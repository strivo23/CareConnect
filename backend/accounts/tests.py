from django.test import TestCase
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.test import APITestCase
from rest_framework import status

from accounts.models import (
    ResidentProfile, VolunteerProfile, SecurityProfile, GuardianProfile, OTPVerification
)
from society.models import Society, BlockTower, Flat
from emergency.models import EmergencyContact, Relationship, VerificationStatus

User = get_user_model()


class RegistrationAndProfileTests(APITestCase):
    def setUp(self):
        self.society = Society.objects.create(
            name="Care Society",
            address="123 Road",
            city="City",
            state="State",
            pincode="123456",
            contact_person="Manager",
            contact_number="9876543210",
            email="manager@care.com",
            status="Active"
        )
        self.block = BlockTower.objects.create(
            society=self.society,
            name="Block A",
            total_floors=5
        )
        self.flat = Flat.objects.create(
            block=self.block,
            flat_number="101",
            floor=1,
            type="2BHK",
            occupied=False
        )
        self.relationship = Relationship.objects.create(name="Family")


    def test_resident_registration_creates_profile(self):
        data = {
            "full_name": "John Resident",
            "email": "resident@example.com",
            "phone_number": "9999999991",
            "password": "strongpassword123",
            "role": "RESIDENT",
            "society": self.society.id,
            "block": self.block.id,
            "flat": self.flat.id
        }
        response = self.client.post("/api/accounts/register/", data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(User.objects.filter(email="resident@example.com").exists())
        self.assertTrue(ResidentProfile.objects.filter(user__email="resident@example.com").exists())
        
        # Verify Registration generated an OTPVerification record
        user = User.objects.get(email="resident@example.com")
        self.assertTrue(OTPVerification.objects.filter(user=user).exists())

    def test_volunteer_registration_creates_profile(self):
        data = {
            "full_name": "Jack Volunteer",
            "email": "volunteer@example.com",
            "phone_number": "9999999992",
            "password": "strongpassword123",
            "role": "VOLUNTEER",
            "skills": "Medical, First Aid",
            "availability": "Weekends",
            "service_area": "Block A"
        }
        response = self.client.post("/api/accounts/register/", data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(VolunteerProfile.objects.filter(user__email="volunteer@example.com").exists())

    def test_password_length_validation(self):
        data = {
            "full_name": "Short Pass User",
            "email": "short@example.com",
            "phone_number": "9999999993",
            "password": "short",
            "role": "RESIDENT"
        }
        response = self.client.post("/api/accounts/register/", data)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        errors = response.data.get("errors", response.data)
        self.assertIn("password", errors)


class OTPVerificationTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="testuser@example.com",
            email="testuser@example.com",
            full_name="Test User",
            password="strongpassword123",
            role="RESIDENT"
        )

    def test_send_and_verify_otp_flow(self):
        # 1. Send OTP
        send_response = self.client.post("/api/auth/send-otp/", {"email": self.user.email})
        self.assertEqual(send_response.status_code, status.HTTP_200_OK)
        self.assertTrue(send_response.data["success"])
        otp = send_response.data["otp"]
        
        # Verify record exists
        self.assertTrue(OTPVerification.objects.filter(user=self.user, otp=otp).exists())

        # 2. Resend OTP immediately should trigger 60s rate limit cooldown
        resend_cooldown_response = self.client.post("/api/auth/resend-otp/", {"email": self.user.email})
        self.assertEqual(resend_cooldown_response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(resend_cooldown_response.data["success"])
        self.assertIn("seconds before requesting a new OTP", resend_cooldown_response.data["message"])

        # 3. Verify with wrong OTP
        verify_fail_response = self.client.post("/api/auth/verify-otp/", {"email": self.user.email, "otp": "000000"})
        self.assertEqual(verify_fail_response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(verify_fail_response.data["success"])

        # 4. Verify with demo fallback code 123456
        verify_demo_response = self.client.post("/api/auth/verify-otp/", {"email": self.user.email, "otp": "123456"})
        self.assertEqual(verify_demo_response.status_code, status.HTTP_200_OK)
        self.assertTrue(verify_demo_response.data["success"])
        
        # Verify user is marked verified in DB
        self.user.refresh_from_db()
        self.assertTrue(self.user.is_verified)


class EmergencyContactTests(APITestCase):
    def setUp(self):
        self.resident = User.objects.create_user(
            username="res1@example.com",
            email="res1@example.com",
            full_name="Resident One",
            password="strongpassword123",
            role="RESIDENT"
        )
        self.other_resident = User.objects.create_user(
            username="res2@example.com",
            email="res2@example.com",
            full_name="Resident Two",
            password="strongpassword123",
            role="RESIDENT"
        )
        self.admin = User.objects.create_superuser(
            username="admin@care.com",
            email="admin@care.com",
            full_name="Admin",
            password="strongpassword123"
        )
        # Set roles explicitly
        self.admin.role = "ADMIN"
        self.admin.save()
        
        self.relationship = Relationship.objects.create(name="Family")

    def test_single_primary_guardian_constraint(self):
        self.client.force_authenticate(user=self.resident)
        
        # Create first primary contact
        c1_data = {
            "name": "Primary Contact",
            "phone": "9876543210",
            "email": "primary@example.com",
            "relationship": self.relationship.id,
            "is_primary": True
        }
        res1 = self.client.post("/api/emergency/contacts/", c1_data)
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)

        # Try to create second primary contact
        c2_data = {
            "name": "Second Primary Contact",
            "phone": "9876543211",
            "email": "secprimary@example.com",
            "relationship": self.relationship.id,
            "is_primary": True
        }
        res2 = self.client.post("/api/emergency/contacts/", c2_data)
        self.assertEqual(res2.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("is_primary", res2.data)

    def test_contact_verification_via_otp(self):
        self.client.force_authenticate(user=self.resident)
        
        # 1. Create contact
        contact = EmergencyContact.objects.create(
            resident=self.resident,
            name="Contact to Verify",
            phone="9876543212",
            email="contact@example.com",
            relationship=self.relationship,
            is_primary=False
        )

        # 2. Trigger send-verification
        send_res = self.client.post("/api/emergency/contacts/send-verification/", {"contact_id": contact.id})
        self.assertEqual(send_res.status_code, status.HTTP_200_OK)
        otp = send_res.data["otp"]

        # 3. Verify OTP
        verify_res = self.client.post("/api/emergency/contacts/verify/", {"contact_id": contact.id, "otp": otp})
        self.assertEqual(verify_res.status_code, status.HTTP_200_OK)
        
        contact.refresh_from_db()
        self.assertTrue(contact.verified)
        self.assertEqual(contact.verification_status.status, "Verified")

    def test_contact_visibility_permissions(self):
        # Create contacts for resident
        contact = EmergencyContact.objects.create(
            resident=self.resident,
            name="Resident Contact",
            phone="9876543212",
            relationship=self.relationship
        )

        # 1. Resident queries contacts (should only see own)
        self.client.force_authenticate(user=self.resident)
        res_response = self.client.get("/api/emergency/contacts/")
        self.assertEqual(res_response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res_response.data["results"]), 1)

        # 2. Other resident queries (should see 0 own contacts)
        self.client.force_authenticate(user=self.other_resident)
        other_response = self.client.get("/api/emergency/contacts/")
        self.assertEqual(other_response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(other_response.data["results"]), 0)

        # 3. Admin queries contacts (should see all)
        self.client.force_authenticate(user=self.admin)
        admin_response = self.client.get("/api/emergency/contacts/")
        self.assertEqual(admin_response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(admin_response.data["results"]), 1)


class ForgotPasswordAndResetPasswordTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="resetuser@example.com",
            email="resetuser@example.com",
            full_name="Reset User",
            password="oldpassword123",
            role="RESIDENT",
            is_active=True
        )

    def test_forgot_password_generates_otp_and_returns_generic_response(self):
        response = self.client.post("/api/auth/forgot-password/", {"email": "resetuser@example.com"})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])
        self.assertEqual(response.data["message"], "If the email is registered, a verification code has been sent.")
        self.assertIn("otp", response.data)

    def test_forgot_password_account_enumeration_protection(self):
        response = self.client.post("/api/auth/forgot-password/", {"email": "nonexistent@example.com"})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])
        self.assertEqual(response.data["message"], "If the email is registered, a verification code has been sent.")
        self.assertNotIn("otp", response.data)

    def test_verify_reset_otp_issues_reset_token(self):
        # Trigger reset
        forgot_res = self.client.post("/api/auth/forgot-password/", {"email": "resetuser@example.com"})
        otp = forgot_res.data["otp"]

        # Verify OTP
        verify_res = self.client.post("/api/auth/verify-reset-otp/", {
            "email": "resetuser@example.com",
            "otp": otp
        })
        self.assertEqual(verify_res.status_code, status.HTTP_200_OK)
        self.assertTrue(verify_res.data["success"])
        self.assertIn("reset_token", verify_res.data)

    def test_verify_reset_otp_invalid_code(self):
        self.client.post("/api/auth/forgot-password/", {"email": "resetuser@example.com"})
        verify_res = self.client.post("/api/auth/verify-reset-otp/", {
            "email": "resetuser@example.com",
            "otp": "000000"
        })
        self.assertEqual(verify_res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(verify_res.data["success"])

    def test_reset_password_success_and_login_with_new_password(self):
        # 1. Request OTP
        forgot_res = self.client.post("/api/auth/forgot-password/", {"email": "resetuser@example.com"})
        otp = forgot_res.data["otp"]

        # 2. Verify OTP -> get reset_token
        verify_res = self.client.post("/api/auth/verify-reset-otp/", {
            "email": "resetuser@example.com",
            "otp": otp
        })
        reset_token = verify_res.data["reset_token"]

        # 3. Reset password
        reset_res = self.client.post("/api/auth/reset-password/", {
            "reset_token": reset_token,
            "new_password": "newpassword123",
            "confirm_password": "newpassword123"
        })
        self.assertEqual(reset_res.status_code, status.HTTP_200_OK)
        self.assertTrue(reset_res.data["success"])

        # 4. Old password login attempt -> 401 Unauthorized
        old_login = self.client.post("/api/accounts/login/", {
            "email": "resetuser@example.com",
            "password": "oldpassword123"
        })
        self.assertEqual(old_login.status_code, status.HTTP_401_UNAUTHORIZED)

        # 5. New password login attempt -> 200 OK + JWT tokens
        new_login = self.client.post("/api/accounts/login/", {
            "email": "resetuser@example.com",
            "password": "newpassword123"
        })
        self.assertEqual(new_login.status_code, status.HTTP_200_OK)
        self.assertIn("access", new_login.data)

