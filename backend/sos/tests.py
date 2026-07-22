"""
sos/tests.py

Comprehensive test suite for the SOS module.

Covers:
  - Model creation & __str__
  - SOSService.create_incident (auto-status, auto-notification)
  - SOSService.update_status (valid and invalid transitions)
  - SOSSendSerializer validation (inactive category, lat/lon bounds, message length)
  - API endpoints: categories, incidents, history, send, status actions
  - Role-based access: Resident, SocietyManager, Security, Admin
  - Search, filter, and ordering params
  - Pagination
"""

from decimal import Decimal

from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from notifications.models import Notification
from .models import EmergencyCategory, SOSIncident
from .services import SOSService

User = get_user_model()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_user(email, role="RESIDENT", **kwargs):
    """Create a CustomUser for testing."""
    user = User.objects.create_user(
        username=email,
        email=email,
        password="testpass123",
        full_name=kwargs.get("full_name", "Test User"),
        role=role,
    )
    return user


def auth_client(client, user):
    """Attach JWT bearer token to the test client."""
    refresh = RefreshToken.for_user(user)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {refresh.access_token}")
    return client


def make_category(name="Fire", is_active=True):
    return EmergencyCategory.objects.create(name=name, is_active=is_active)


def make_incident(resident, category, status_val="Pending", **kwargs):
    return SOSIncident.objects.create(
        resident=resident,
        category=category,
        status=status_val,
        message=kwargs.get("message", "Help needed"),
        latitude=kwargs.get("latitude", Decimal("12.9716")),
        longitude=kwargs.get("longitude", Decimal("77.5946")),
    )


# ---------------------------------------------------------------------------
# Model tests
# ---------------------------------------------------------------------------

class EmergencyCategoryModelTest(APITestCase):
    def test_str(self):
        cat = make_category("Medical")
        self.assertEqual(str(cat), "Medical")

    def test_default_is_active(self):
        cat = EmergencyCategory.objects.create(name="Gas Leak")
        self.assertTrue(cat.is_active)


class SOSIncidentModelTest(APITestCase):
    def setUp(self):
        self.user = make_user("resident@test.com")
        self.cat = make_category()

    def test_str(self):
        inc = make_incident(self.user, self.cat)
        self.assertIn("Fire", str(inc))
        self.assertIn("Pending", str(inc))

    def test_default_status_is_pending(self):
        inc = SOSIncident.objects.create(resident=self.user, category=self.cat)
        self.assertEqual(inc.status, "Pending")


# ---------------------------------------------------------------------------
# Service tests
# ---------------------------------------------------------------------------

class SOSServiceCreateTest(APITestCase):
    def setUp(self):
        self.user = make_user("res@test.com")
        self.cat = make_category()

    def test_creates_incident_with_pending_status(self):
        incident = SOSService.create_incident(
            self.user, {"category": self.cat, "message": "Help!"}
        )
        self.assertEqual(incident.status, "Pending")
        self.assertEqual(incident.resident, self.user)

    def test_auto_creates_notification(self):
        SOSService.create_incident(self.user, {"category": self.cat})
        self.assertTrue(
            Notification.objects.filter(user=self.user, category="sos").exists()
        )

    def test_notification_title_contains_alert(self):
        SOSService.create_incident(self.user, {"category": self.cat})
        notif = Notification.objects.filter(user=self.user, category="sos").first()
        self.assertIn("Alert", notif.title)

    def test_notifies_primary_and_verified_guardians(self):
        from emergency.models import EmergencyContact
        # Create guardian users
        g1 = make_user("guardian1@test.com", role="RESIDENT", full_name="G One")
        g1.phone_number = "+919876543210"
        g1.save()

        g2 = make_user("guardian2@test.com", role="RESIDENT", full_name="G Two")
        g2.phone_number = "+919876543211"
        g2.save()

        # Resident contact setup
        # Contact 1: Primary
        EmergencyContact.objects.create(
            resident=self.user,
            name="G One",
            phone="+919876543210",
            is_primary=True,
            verified=False
        )
        # Contact 2: Verified
        EmergencyContact.objects.create(
            resident=self.user,
            name="G Two",
            phone="+919876543211",
            is_primary=False,
            verified=True
        )

        incident = SOSService.create_incident(
            self.user,
            {"category": self.cat, "message": "Fire!"}
        )

        # Assert notifications exist
        notif_g1 = Notification.objects.filter(user=g1, category="sos", priority="HIGH", incident=incident).first()
        self.assertIsNotNone(notif_g1)
        self.assertEqual(notif_g1.title, "Emergency SOS")
        self.assertEqual(notif_g1.message, f"{self.user.full_name} needs immediate assistance.")

        notif_g2 = Notification.objects.filter(user=g2, category="sos", priority="HIGH", incident=incident).first()
        self.assertIsNotNone(notif_g2)



class SOSServiceUpdateStatusTest(APITestCase):
    def setUp(self):
        self.user = make_user("res2@test.com")
        self.cat = make_category("Flood")
        self.incident = make_incident(self.user, self.cat, "Pending")

    def test_valid_transition_pending_to_accepted(self):
        updated = SOSService.update_status(self.incident, "Accepted")
        self.assertEqual(updated.status, "Accepted")

    def test_valid_chain_pending_accepted_inprogress_resolved(self):
        SOSService.update_status(self.incident, "Accepted")
        SOSService.update_status(self.incident, "In Progress")
        SOSService.update_status(self.incident, "Resolved")
        self.incident.refresh_from_db()
        self.assertEqual(self.incident.status, "Resolved")

    def test_invalid_transition_raises_value_error(self):
        with self.assertRaises(ValueError):
            SOSService.update_status(self.incident, "Resolved")  # Pending → Resolved invalid

    def test_terminal_state_cannot_transition(self):
        SOSService.update_status(self.incident, "Cancelled")
        with self.assertRaises(ValueError):
            SOSService.update_status(self.incident, "Accepted")

    def test_status_change_creates_notification(self):
        SOSService.update_status(self.incident, "Accepted")
        self.assertTrue(
            Notification.objects.filter(user=self.user, category="sos").exists()
        )


# ---------------------------------------------------------------------------
# Serializer validation tests
# ---------------------------------------------------------------------------

class SOSSendSerializerValidationTest(APITestCase):
    def setUp(self):
        self.resident = make_user("val@test.com")
        self.active_cat = make_category("Active Cat", is_active=True)
        self.inactive_cat = make_category("Inactive Cat", is_active=False)
        auth_client(self.client, self.resident)

    def _post(self, payload):
        return self.client.post(reverse("sos-send"), payload, format="json")

    def test_inactive_category_rejected(self):
        res = self._post({"category": self.inactive_cat.id, "message": "Help"})
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("inactive", str(res.data).lower())

    def test_latitude_out_of_range(self):
        res = self._post({
            "category": self.active_cat.id,
            "latitude": "91.0",
            "longitude": "0.0",
        })
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_longitude_out_of_range(self):
        res = self._post({
            "category": self.active_cat.id,
            "latitude": "0.0",
            "longitude": "181.0",
        })
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_message_too_long(self):
        res = self._post({
            "category": self.active_cat.id,
            "message": "x" * 501,
        })
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_valid_send(self):
        res = self._post({
            "category": self.active_cat.id,
            "message": "Help me",
            "latitude": "12.97",
            "longitude": "77.59",
        })
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data["status"], "Pending")


# ---------------------------------------------------------------------------
# Categories endpoint
# ---------------------------------------------------------------------------

class EmergencyCategoryAPITest(APITestCase):
    def setUp(self):
        self.user = make_user("cat@test.com")
        auth_client(self.client, self.user)
        self.active = make_category("Fire")
        make_category("Inactive", is_active=False)

    def test_returns_only_active_categories(self):
        res = self.client.get(reverse("sos-categories"))
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        names = [c["name"] for c in res.data["results"]]
        self.assertIn("Fire", names)
        self.assertNotIn("Inactive", names)

    def test_unauthenticated_denied(self):
        self.client.credentials()
        res = self.client.get(reverse("sos-categories"))
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)


# ---------------------------------------------------------------------------
# Incident list / detail
# ---------------------------------------------------------------------------

class SOSIncidentListAPITest(APITestCase):
    def setUp(self):
        self.resident = make_user("r@test.com", role="RESIDENT")
        self.other = make_user("other@test.com", role="RESIDENT")
        self.manager = make_user("mgr@test.com", role="ADMIN")
        self.cat = make_category()
        self.mine = make_incident(self.resident, self.cat)
        self.theirs = make_incident(self.other, self.cat)

    def test_resident_sees_only_own(self):
        auth_client(self.client, self.resident)
        res = self.client.get(reverse("sos-incident-list"))
        self.assertEqual(res.status_code, 200)
        ids = [i["id"] for i in res.data["results"]]
        self.assertIn(self.mine.id, ids)
        self.assertNotIn(self.theirs.id, ids)

    def test_admin_sees_all(self):
        auth_client(self.client, self.manager)
        res = self.client.get(reverse("sos-incident-list"))
        ids = [i["id"] for i in res.data["results"]]
        self.assertIn(self.mine.id, ids)
        self.assertIn(self.theirs.id, ids)

    def test_filter_by_status(self):
        auth_client(self.client, self.manager)
        make_incident(self.resident, self.cat, status_val="Resolved")
        res = self.client.get(reverse("sos-incident-list") + "?status=Resolved")
        for item in res.data["results"]:
            self.assertEqual(item["status"], "Resolved")

    def test_search_by_category_name(self):
        auth_client(self.client, self.manager)
        res = self.client.get(reverse("sos-incident-list") + f"?search={self.cat.name}")
        self.assertGreater(len(res.data["results"]), 0)

    def test_ordering_by_created_at_desc(self):
        auth_client(self.client, self.manager)
        res = self.client.get(reverse("sos-incident-list") + "?ordering=-created_at")
        dates = [i["created_at"] for i in res.data["results"]]
        self.assertEqual(dates, sorted(dates, reverse=True))

    def test_pagination_returns_standard_keys(self):
        auth_client(self.client, self.manager)
        res = self.client.get(reverse("sos-incident-list"))
        self.assertIn("count", res.data)
        self.assertIn("next", res.data)
        self.assertIn("previous", res.data)
        self.assertIn("results", res.data)


# ---------------------------------------------------------------------------
# History endpoint
# ---------------------------------------------------------------------------

class SOSHistoryAPITest(APITestCase):
    def setUp(self):
        self.resident = make_user("hist@test.com")
        self.other = make_user("other2@test.com")
        self.cat = make_category("History Cat")
        make_incident(self.resident, self.cat)
        make_incident(self.other, self.cat)
        auth_client(self.client, self.resident)

    def test_history_returns_only_own(self):
        res = self.client.get(reverse("sos-history"))
        self.assertEqual(res.status_code, 200)
        for item in res.data["results"]:
            self.assertEqual(item["resident"], self.resident.id)


# ---------------------------------------------------------------------------
# Status-change actions
# ---------------------------------------------------------------------------

class SOSStatusActionTest(APITestCase):
    def setUp(self):
        self.resident = make_user("act_res@test.com", role="RESIDENT")
        self.manager = make_user("act_mgr@test.com", role="ADMIN")
        self.cat = make_category("Action Cat")
        self.incident = make_incident(self.resident, self.cat, "Pending")

    def test_accept_by_manager(self):
        auth_client(self.client, self.manager)
        url = reverse("sos-accept", kwargs={"pk": self.incident.pk})
        res = self.client.patch(url, {}, format="json")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["status"], "Accepted")

    def test_in_progress_after_accepted(self):
        auth_client(self.client, self.manager)
        self.client.patch(reverse("sos-accept", kwargs={"pk": self.incident.pk}))
        res = self.client.patch(reverse("sos-in-progress", kwargs={"pk": self.incident.pk}))
        self.assertEqual(res.data["status"], "In Progress")

    def test_resolve_after_in_progress(self):
        auth_client(self.client, self.manager)
        self.client.patch(reverse("sos-accept", kwargs={"pk": self.incident.pk}))
        self.client.patch(reverse("sos-in-progress", kwargs={"pk": self.incident.pk}))
        res = self.client.patch(reverse("sos-resolve", kwargs={"pk": self.incident.pk}))
        self.assertEqual(res.data["status"], "Resolved")

    def test_invalid_transition_returns_400(self):
        auth_client(self.client, self.manager)
        # Skip Accepted, try to resolve directly from Pending
        res = self.client.patch(reverse("sos-resolve", kwargs={"pk": self.incident.pk}))
        self.assertEqual(res.status_code, 400)

    def test_resident_cannot_accept(self):
        auth_client(self.client, self.resident)
        url = reverse("sos-accept", kwargs={"pk": self.incident.pk})
        res = self.client.patch(url, {}, format="json")
        self.assertEqual(res.status_code, 403)

    def test_resident_can_cancel_own(self):
        auth_client(self.client, self.resident)
        url = reverse("sos-cancel", kwargs={"pk": self.incident.pk})
        res = self.client.patch(url, {}, format="json")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["status"], "Cancelled")

    def test_resident_cannot_cancel_others(self):
        other = make_user("other_cancel@test.com", role="RESIDENT")
        auth_client(self.client, other)
        url = reverse("sos-cancel", kwargs={"pk": self.incident.pk})
        res = self.client.patch(url, {}, format="json")
        self.assertEqual(res.status_code, 403)

    def test_404_for_nonexistent_incident(self):
        auth_client(self.client, self.manager)
        res = self.client.patch(reverse("sos-accept", kwargs={"pk": 999999}))
        self.assertEqual(res.status_code, 404)


# ---------------------------------------------------------------------------
# Location and Messaging Day 8 Tests
# ---------------------------------------------------------------------------

class SOSLocationAndMessagingTests(APITestCase):
    def setUp(self):
        self.resident = make_user("res_loc@test.com", role="RESIDENT")
        self.other = make_user("other_loc@test.com", role="RESIDENT")
        self.manager = make_user("man_loc@test.com", role="SOCIETY_MANAGER")
        self.category = make_category("Fire")
        self.incident = make_incident(self.resident, self.category)

    def test_reverse_geocode_api(self):
        auth_client(self.client, self.resident)
        url = reverse("geocode-reverse")
        # Test missing params
        res = self.client.get(url)
        self.assertEqual(res.status_code, 400)

        # Test valid request
        res = self.client.get(url, {"latitude": "12.9716", "longitude": "77.5946"})
        self.assertEqual(res.status_code, 200)
        self.assertIn("address", res.data)

        # Test invalid coordinate values
        res = self.client.get(url, {"latitude": "100", "longitude": "200"})
        self.assertEqual(res.status_code, 400)

    def test_patch_incident_details(self):
        auth_client(self.client, self.resident)
        url = reverse("sos-update", kwargs={"pk": self.incident.pk})

        # Test updating priority, message, and location
        data = {
            "message": "Immediate water leakage threat",
            "priority": "CRITICAL",
            "latitude": "12.9123456",
            "longitude": "77.5678901",
        }
        res = self.client.patch(url, data, format="json")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["priority"], "CRITICAL")
        self.assertEqual(res.data["message"], "Immediate water leakage threat")

    def test_other_resident_cannot_patch(self):
        auth_client(self.client, self.other)
        url = reverse("sos-update", kwargs={"pk": self.incident.pk})
        res = self.client.patch(url, {"message": "hacked"}, format="json")
        self.assertEqual(res.status_code, 403)

    def test_emergency_messages_flow(self):
        auth_client(self.client, self.resident)
        url_create = reverse("sos-message-create", kwargs={"pk": self.incident.pk})
        url_list = reverse("sos-message-list", kwargs={"pk": self.incident.pk})

        # Create message
        res = self.client.post(url_create, {"message": "We need extra blankets!"}, format="json")
        self.assertEqual(res.status_code, 201)
        self.assertEqual(res.data["message"], "We need extra blankets!")
        self.assertEqual(res.data["sender_email"], self.resident.email)

        # List messages
        res = self.client.get(url_list)
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.data), 1)
        self.assertEqual(res.data[0]["message"], "We need extra blankets!")

    def test_other_resident_cannot_post_message(self):
        auth_client(self.client, self.other)
        url = reverse("sos-message-create", kwargs={"pk": self.incident.pk})
        res = self.client.post(url, {"message": "fake text"}, format="json")
        self.assertEqual(res.status_code, 403)


class Milestone2FeaturesTest(APITestCase):
    def setUp(self):
        self.admin = make_user("admin@cc.com", role="ADMIN", full_name="Admin User")
        self.resident = make_user("resident@cc.com", role="RESIDENT", full_name="Resident User")
        self.volunteer = make_user("volunteer@cc.com", role="VOLUNTEER", full_name="Volunteer User")
        self.cat = make_category("Fire")

        # Create volunteer profile with location
        from accounts.models import VolunteerProfile
        # Volunteer profile is automatically created in registration, but let's update or ensure it exists
        self.vol_profile, _ = VolunteerProfile.objects.get_or_create(
            user=self.volunteer,
            defaults={
                'skills': 'First Aid',
                'availability': 'Online',
                'service_area': 'Central Block',
                'is_online': True,
                'latitude': Decimal("12.9716"),
                'longitude': Decimal("77.5946"),
                'visibility_radius': 5000.0
            }
        )
        self.vol_profile.is_online = True
        self.vol_profile.latitude = Decimal("12.9716")
        self.vol_profile.longitude = Decimal("77.5946")
        self.vol_profile.visibility_radius = 5000.0
        self.vol_profile.save()

    def test_device_token_registration(self):
        auth_client(self.client, self.resident)
        url = reverse("device-list")
        res = self.client.post(url, {"token": "fcm_test_device_token_123"}, format="json")
        self.assertEqual(res.status_code, 201)
        from notifications.models import FCMDevice
        self.assertTrue(FCMDevice.objects.filter(user=self.resident, token="fcm_test_device_token_123").exists())

    def test_escalation_workflow_scheduled_on_create(self):
        auth_client(self.client, self.resident)
        url = reverse("sos-send")
        data = {
            "category": self.cat.id,
            "message": "Gas leak in kitchen!",
            "latitude": "12.9716",
            "longitude": "77.5946"
        }
        res = self.client.post(url, data, format="json")
        self.assertEqual(res.status_code, 201)
        incident_id = res.data["id"]

        from sos.models import EscalationLog
        logs = EscalationLog.objects.filter(incident_id=incident_id)
        self.assertEqual(logs.count(), 4)
        
        # Primary Guardian should be triggered immediately
        primary = logs.get(step="Primary Guardian")
        self.assertEqual(primary.status, "TRIGGERED")

        # Others should be pending
        secondary = logs.get(step="Secondary Guardian")
        self.assertEqual(secondary.status, "PENDING")

    def test_community_broadcast_notifies_nearby_volunteers(self):
        auth_client(self.client, self.resident)
        # Create incident
        incident = make_incident(self.resident, self.cat, latitude=Decimal("12.9716"), longitude=Decimal("77.5946"))
        
        auth_client(self.client, self.admin)
        url = reverse("sos-incident-broadcast", kwargs={"pk": incident.pk})
        res = self.client.post(url, format="json")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["volunteers_notified"], 1)

    def test_incident_tracking_stats(self):
        auth_client(self.client, self.admin)
        url = reverse("sos-incident-stats")
        res = self.client.get(url)
        self.assertEqual(res.status_code, 200)
        self.assertIn("total_incidents", res.data)
        self.assertIn("status_counts", res.data)
        self.assertIn("delivery_stats", res.data)

