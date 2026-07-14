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
