from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken
from sos.models import EmergencyCategory, SOSIncident
from notifications.models import Notification

User = get_user_model()

class EmergencyAlertAPITest(APITestCase):
    def setUp(self):
        self.resident = User.objects.create_user(
            username="res@test.com",
            email="res@test.com",
            password="password123",
            full_name="Resident User",
            role="RESIDENT"
        )
        refresh = RefreshToken.for_user(self.resident)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {refresh.access_token}")
        
        # Pre-create an active category
        self.active_cat = EmergencyCategory.objects.create(name="Fire", is_active=True)
        # Pre-create an inactive category
        self.inactive_cat = EmergencyCategory.objects.create(name="Ambulance", is_active=False)

    def test_trigger_sos_with_new_category(self):
        url = reverse("emergency-alerts")
        data = {
            "category": "Police",
            "message": "Need urgent help"
        }
        response = self.client.post(url, data, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn("incident", response.data)
        
        # Verify category was created
        self.assertTrue(EmergencyCategory.objects.filter(name="Police").exists())
        
        # Verify incident was created
        incident = SOSIncident.objects.filter(resident=self.resident, category__name="Police").first()
        self.assertIsNotNone(incident)
        self.assertEqual(incident.status, "Pending")
        self.assertEqual(incident.message, "Need urgent help")

        # Verify notification was created
        self.assertTrue(Notification.objects.filter(user=self.resident, category="sos").exists())

    def test_trigger_sos_with_existing_active_category(self):
        url = reverse("emergency-alerts")
        data = {
            "category": "fire", # lower case to test case insensitivity
            "message": "Fire in block A"
        }
        response = self.client.post(url, data, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        
        incident = SOSIncident.objects.filter(resident=self.resident, category=self.active_cat).first()
        self.assertIsNotNone(incident)

    def test_trigger_sos_with_inactive_category_fails(self):
        url = reverse("emergency-alerts")
        data = {
            "category": "ambulance",
            "message": "Medical emergency"
        }
        response = self.client.post(url, data, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("inactive", response.data["detail"])

    def test_unauthenticated_user_denied(self):
        self.client.credentials() # Clear auth credentials
        url = reverse("emergency-alerts")
        data = {"category": "Fire"}
        response = self.client.post(url, data, format="json")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class GuardianConnectionAPITests(APITestCase):
    def setUp(self):
        self.user1 = User.objects.create_user(
            username="user1@test.com",
            email="user1@test.com",
            password="pass123",
            full_name="User One",
            role="RESIDENT"
        )
        self.user2 = User.objects.create_user(
            username="user2@test.com",
            email="user2@test.com",
            password="pass123",
            full_name="User Two",
            role="RESIDENT"
        )
        from accounts.models import GuardianProfile
        self.profile2, _ = GuardianProfile.objects.get_or_create(user=self.user2)
        self.profile2.guardian_code = "CC-GD-TEST2"
        self.profile2.save()

        ref1 = RefreshToken.for_user(self.user1)
        self.token1 = str(ref1.access_token)

        ref2 = RefreshToken.for_user(self.user2)
        self.token2 = str(ref2.access_token)

    def test_generate_and_get_guardian_code(self):
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {self.token1}")
        url = reverse("guardian-my-code")
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])
        self.assertIsNotNone(response.data["guardian_code"])

    def test_link_guardian_valid_code(self):
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {self.token1}")
        url = reverse("resident-link-guardian")
        payload = {
            "guardian_code": "CC-GD-TEST2",
            "relationship": "Brother",
            "is_primary": True
        }
        response = self.client.post(url, payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(response.data["success"])
        self.assertIn("message", response.data)

    def test_link_guardian_invalid_code_returns_404(self):
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {self.token1}")
        url = reverse("resident-link-guardian")
        payload = {"guardian_code": "INVALID-CODE"}
        response = self.client.post(url, payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertFalse(response.data["success"])

    def test_link_guardian_self_link_fails(self):
        from accounts.models import GuardianProfile
        p1, _ = GuardianProfile.objects.get_or_create(user=self.user1)
        p1.guardian_code = "CC-GD-TEST1"
        p1.save()

        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {self.token1}")
        url = reverse("resident-link-guardian")
        payload = {"guardian_code": "CC-GD-TEST1"}
        response = self.client.post(url, payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(response.data["success"])

    def test_link_guardian_duplicate_fails_409(self):
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {self.token1}")
        url = reverse("resident-link-guardian")
        payload = {"guardian_code": "CC-GD-TEST2"}
        r1 = self.client.post(url, payload, format="json")
        self.assertEqual(r1.status_code, status.HTTP_201_CREATED)

        r2 = self.client.post(url, payload, format="json")
        self.assertEqual(r2.status_code, status.HTTP_409_CONFLICT)
        self.assertFalse(response_data_success := r2.data["success"])

    def test_accept_and_reject_guardian_request(self):
        from emergency.models import ResidentGuardian
        link = ResidentGuardian.objects.create(
            resident=self.user1,
            guardian=self.user2,
            relationship_name="Friend",
            status="Pending"
        )
        url = reverse("guardian-respond-link")
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {self.token2}")

        response = self.client.post(url, {"link_id": link.id, "action": "accept"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])
        self.assertEqual(response.data["status"], "Active")

        link.refresh_from_db()
        self.assertEqual(link.status, "Active")


class GuardianSOSWorkflowTests(APITestCase):
    def setUp(self):
        self.resident = User.objects.create_user(
            username="resident@test.com",
            email="resident@test.com",
            password="pass123",
            full_name="Resident User",
            role="RESIDENT"
        )
        self.primary_guardian = User.objects.create_user(
            username="primary@test.com",
            email="primary@test.com",
            password="pass123",
            full_name="Primary Guardian",
            role="RESIDENT"
        )
        self.secondary_guardian = User.objects.create_user(
            username="secondary@test.com",
            email="secondary@test.com",
            password="pass123",
            full_name="Secondary Guardian",
            role="RESIDENT"
        )

        from emergency.models import ResidentGuardian
        ResidentGuardian.objects.create(
            resident=self.resident,
            guardian=self.primary_guardian,
            relationship_name="Parent",
            is_primary=True,
            status="Active"
        )
        ResidentGuardian.objects.create(
            resident=self.resident,
            guardian=self.secondary_guardian,
            relationship_name="Sibling",
            is_primary=False,
            status="Active"
        )

    def test_guardian_receives_in_app_notification_when_resident_triggers_sos(self):
        from sos.services import SOSService
        from sos.models import EmergencyCategory, SOSIncident
        from notifications.models import Notification

        cat = EmergencyCategory.objects.create(name="Medical Emergency", is_active=True)
        incident = SOSService.create_incident(
            user=self.resident,
            validated_data={
                "category": cat,
                "message": "Chest pain, need help!",
                "latitude": 13.0827,
                "longitude": 80.2707,
                "address": "123 Test Street",
                "priority": "HIGH"
            }
        )

        # 1. Verify Notification created for Primary Guardian
        primary_notif = Notification.objects.filter(user=self.primary_guardian, incident=incident).first()
        self.assertIsNotNone(primary_notif)
        self.assertFalse(primary_notif.is_read)
        self.assertEqual(primary_notif.category, "sos")

        # 2. Verify Notification created for Secondary Guardian
        secondary_notif = Notification.objects.filter(user=self.secondary_guardian, incident=incident).first()
        self.assertIsNotNone(secondary_notif)
        self.assertFalse(secondary_notif.is_read)
        self.assertEqual(secondary_notif.category, "sos")

        # 3. Test Guardian Dashboard API for Primary Guardian
        ref = RefreshToken.for_user(self.primary_guardian)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {ref.access_token}")
        response = self.client.get("/api/guardian/dashboard/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])
        self.assertEqual(len(response.data["active_alerts"]), 1)
        self.assertEqual(response.data["active_alerts"][0]["id"], incident.id)

        # 4. Test Guardian Notifications API
        response_notif = self.client.get("/api/notifications/guardian/")
        self.assertEqual(response_notif.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(response_notif.data), 1)


