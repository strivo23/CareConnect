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
        phone_number=kwargs.get("phone_number", ""),
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
        # Contact 2: Verified Primary Guardian
        EmergencyContact.objects.create(
            resident=self.user,
            name="G Two",
            phone="+919876543211",
            is_primary=True,
            verified=True
        )

        incident = SOSService.create_incident(
            self.user,
            {"category": self.cat, "message": "Fire!"}
        )

        # Assert notifications exist
        notif_g1 = Notification.objects.filter(user=g1, category="sos", priority="HIGH", incident=incident).first()
        self.assertIsNotNone(notif_g1)
        self.assertIn("Emergency SOS", notif_g1.title)
        self.assertTrue(notif_g1.message.startswith(f"{self.user.full_name} needs immediate assistance"))

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
        self.assertIn(res.status_code, [200, 201])
        self.assertEqual(res.data["emergency_description"], "We need extra blankets!")


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
        self.vol_profile.status = "Approved"
        self.vol_profile.availability_status = "ONLINE"
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
        self.assertGreaterEqual(logs.count(), 4)
        
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

    def test_sos_message_upload_validation_and_success(self):
        from django.core.files.uploadedfile import SimpleUploadedFile
        auth_client(self.client, self.resident)
        incident = make_incident(self.resident, self.cat)
        url = reverse("sos-message-create", kwargs={"pk": incident.pk})

        # 1. Reject empty request
        res = self.client.post(url, {}, format="multipart")
        self.assertEqual(res.status_code, 400)

        # 2. Text only
        res_text = self.client.post(url, {"emergency_description": "Medical emergency on 2nd floor"}, format="multipart")
        self.assertEqual(res_text.status_code, 200)
        self.assertEqual(res_text.data["emergency_description"], "Medical emergency on 2nd floor")

        # 3. Voice only
        audio_file = SimpleUploadedFile("voice.mp3", b"audio content bytes", content_type="audio/mp3")
        res_voice = self.client.post(url, {"voice_message": audio_file}, format="multipart")
        self.assertEqual(res_voice.status_code, 200)
        self.assertTrue(res_voice.data["voice_message"])

        # 4. Both text and voice
        audio_file2 = SimpleUploadedFile("voice2.mp3", b"more audio bytes", content_type="audio/mp3")
        res_both = self.client.post(
            url,
            {"emergency_description": "Updated detail text", "voice_message": audio_file2},
            format="multipart"
        )
        self.assertEqual(res_both.status_code, 200)
        self.assertEqual(res_both.data["emergency_description"], "Updated detail text")
        self.assertTrue(res_both.data["voice_message"])


class GuardianEscalationWorkflowDay11Test(APITestCase):
    def setUp(self):
        self.resident = make_user("res_day11@test.com", role="RESIDENT", full_name="Resident Day11")
        self.guardian1 = make_user("guard1@test.com", role="GUARDIAN", full_name="Guardian One")
        self.guardian2 = make_user("guard2@test.com", role="GUARDIAN", full_name="Guardian Two")
        self.admin = make_user("admin_day11@test.com", role="ADMIN", full_name="Admin Day11")
        self.cat = make_category("Day11 Emergency")

    def test_escalation_config_api_get_and_put(self):
        auth_client(self.client, self.admin)
        url = "/api/escalation/config/"
        res = self.client.get(url)
        if res.status_code == 301:
            url = res.headers.get("Location", url)
            res = self.client.get(url)
        self.assertEqual(res.status_code, 200)
        self.assertIn("response_time_minutes", res.data)

        put_res = self.client.put(url, {"response_time_minutes": 10, "notify_volunteers": False}, format="json")
        self.assertEqual(put_res.status_code, 200)
        self.assertEqual(put_res.data["response_time_minutes"], 10)
        self.assertFalse(put_res.data["notify_volunteers"])

    def test_incident_accept_stops_escalation(self):
        auth_client(self.client, self.resident)
        incident = make_incident(self.resident, self.cat)

        vol = make_user("vol_esc@test.com", role="VOLUNTEER")
        auth_client(self.client, vol)
        accept_url = f"/api/incident/{incident.id}/accept/"
        res = self.client.post(accept_url)
        self.assertEqual(res.status_code, 200)
        
        incident.refresh_from_db()
        self.assertIn(incident.status, ["Accepted", "Assigned"])

        # Check logs
        from sos.models import EscalationLog
        pending = EscalationLog.objects.filter(incident=incident, status="PENDING")
        self.assertEqual(pending.count(), 0)

    def test_incident_reject_triggers_immediate_escalation(self):
        auth_client(self.client, self.resident)
        incident = make_incident(self.resident, self.cat)

        auth_client(self.client, self.guardian1)
        reject_url = f"/api/incident/{incident.id}/reject/"
        res = self.client.post(reject_url, {"reason": "Not available"}, format="json")
        self.assertEqual(res.status_code, 200)
        
        from sos.models import EscalationLog
        rejected_log = EscalationLog.objects.filter(incident=incident, status="REJECTED").first()
        self.assertIsNotNone(rejected_log)

    def test_incident_escalation_detail_api(self):
        auth_client(self.client, self.resident)
        incident = make_incident(self.resident, self.cat)

        auth_client(self.client, self.admin)
        url = f"/api/incident/{incident.id}/escalation/"
        res = self.client.get(url)
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["incident_id"], incident.id)
        self.assertIn("escalation_history", res.data)


class Day14ResponderAssignmentTest(APITestCase):
    def setUp(self):
        self.resident = make_user("resident_d14@test.com", role="RESIDENT", full_name="Rahul Resident")
        self.volunteer = make_user("volunteer_d14@test.com", role="VOLUNTEER", full_name="Rahul Volunteer")
        self.security = make_user("security_d14@test.com", role="SECURITY", full_name="John Security")
        self.guardian = make_user("guardian_d14@test.com", role="GUARDIAN", full_name="Guard One")
        self.admin = make_user("admin_d14@test.com", role="ADMIN", full_name="Admin User")
        self.cat = make_category("Day 14 Category")

        from emergency.models import EmergencyContact
        EmergencyContact.objects.create(
            resident=self.resident,
            name="Guard One",
            phone=self.guardian.phone_number or "+919999999999",
            is_primary=True,
            verified=True
        )

    def test_volunteer_accepts_incident_successfully(self):
        incident = make_incident(self.resident, self.cat)
        auth_client(self.client, self.volunteer)

        url = f"/api/sos/incidents/{incident.id}/accept/"
        res = self.client.post(url)

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["success"])
        self.assertEqual(res.data["assigned_to"], "Rahul Volunteer")
        self.assertEqual(res.data["status"], "Accepted")

        incident.refresh_from_db()
        self.assertEqual(incident.assigned_responder, self.volunteer)
        self.assertEqual(incident.assigned_role, "Volunteer")
        self.assertEqual(incident.status, "Accepted")
        self.assertEqual(incident.assignment_status, "Assigned")
        self.assertIsNotNone(incident.accepted_at)

        # Verify audit log created
        from sos.models import AssignmentLog
        log = AssignmentLog.objects.filter(incident=incident, responder=self.volunteer).first()
        self.assertIsNotNone(log)
        self.assertEqual(log.role, "Volunteer")
        self.assertEqual(log.new_status, "Assigned")

        # Verify resident notification
        notif_res = Notification.objects.filter(user=self.resident, category="sos").first()
        self.assertIsNotNone(notif_res)
        self.assertIn("Rahul Volunteer has accepted your", notif_res.message)

    def test_security_accepts_incident_successfully(self):
        incident = make_incident(self.resident, self.cat)
        auth_client(self.client, self.security)

        url = f"/api/sos/incidents/{incident.id}/accept/"
        res = self.client.post(url)

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["success"])
        self.assertEqual(res.data["assigned_to"], "John Security")

        incident.refresh_from_db()
        self.assertEqual(incident.assigned_responder, self.security)
        self.assertEqual(incident.assigned_role, "Security")

    def test_unauthorized_role_acceptance_blocked(self):
        incident = make_incident(self.resident, self.cat)

        # Resident attempts accept
        auth_client(self.client, self.resident)
        url = f"/api/sos/incidents/{incident.id}/accept/"
        res = self.client.post(url)
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # Guardian attempts accept
        auth_client(self.client, self.guardian)
        res = self.client.post(url)
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # Admin attempts accept
        auth_client(self.client, self.admin)
        res = self.client.post(url)
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_duplicate_assignment_returns_409_conflict(self):
        incident = make_incident(self.resident, self.cat)

        # First acceptance by Volunteer
        auth_client(self.client, self.volunteer)
        url = f"/api/sos/incidents/{incident.id}/accept/"
        res1 = self.client.post(url)
        self.assertEqual(res1.status_code, status.HTTP_200_OK)

        # Second acceptance by Security
        auth_client(self.client, self.security)
        res2 = self.client.post(url)
        self.assertEqual(res2.status_code, status.HTTP_409_CONFLICT)
        self.assertFalse(res2.data["success"])
        self.assertEqual(res2.data["message"], "This incident has already been assigned.")

    def test_non_existent_incident_returns_404(self):
        auth_client(self.client, self.volunteer)
        url = "/api/sos/incidents/999999/accept/"
        res = self.client.post(url)
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)


class Day15IncidentLifecycleTest(APITestCase):
    def setUp(self):
        self.cat = make_category("Medical Emergency")
        self.resident = make_user("res_d15@test.com", role="RESIDENT")
        self.volunteer = make_user("vol_d15@test.com", role="VOLUNTEER")
        self.security = make_user("sec_d15@test.com", role="SECURITY")
        self.admin = make_user("admin_d15@test.com", role="ADMIN")

    def test_lifecycle_state_transitions_success_path(self):
        incident = make_incident(self.resident, self.cat)
        self.assertEqual(incident.current_status, "OPEN")

        # 1. OPEN -> ACTIVE by Volunteer
        auth_client(self.client, self.volunteer)
        url_status = f"/api/sos/incidents/{incident.id}/status/"
        res1 = self.client.post(url_status, {"status": "ACTIVE", "remarks": "Volunteer responding"}, format="json")
        self.assertEqual(res1.status_code, status.HTTP_200_OK)
        self.assertTrue(res1.data["success"])
        incident.refresh_from_db()
        self.assertEqual(incident.current_status, "ACTIVE")
        self.assertIsNotNone(incident.active_at)

        # 2. ACTIVE -> ESCALATED by Security
        auth_client(self.client, self.security)
        res2 = self.client.post(url_status, {"status": "ESCALATED", "remarks": "Reinforcements needed"}, format="json")
        self.assertEqual(res2.status_code, status.HTTP_200_OK)
        incident.refresh_from_db()
        self.assertEqual(incident.current_status, "ESCALATED")
        self.assertIsNotNone(incident.escalated_at)

        # 3. ESCALATED -> RESOLVED by Security
        res3 = self.client.post(url_status, {"status": "RESOLVED", "remarks": "Site secured"}, format="json")
        self.assertEqual(res3.status_code, status.HTTP_200_OK)
        incident.refresh_from_db()
        self.assertEqual(incident.current_status, "RESOLVED")
        self.assertIsNotNone(incident.resolved_at)
        self.assertEqual(incident.resolved_by, self.security)

        # 4. RESOLVED -> CLOSED via Closure Documentation API
        auth_client(self.client, self.admin)
        url_closure = f"/api/sos/incidents/{incident.id}/closure/"
        closure_payload = {
            "resolution_summary": "Medical team treated resident on site.",
            "closure_reason": "Issue Resolved",
            "closure_notes": "All clear, resident safe."
        }
        res4 = self.client.post(url_closure, closure_payload, format="json")
        self.assertEqual(res4.status_code, status.HTTP_200_OK)
        incident.refresh_from_db()
        self.assertEqual(incident.current_status, "CLOSED")
        self.assertIsNotNone(incident.closed_at)
        self.assertEqual(incident.closed_by, self.admin)
        self.assertEqual(incident.resolution_summary, "Medical team treated resident on site.")

    def test_invalid_transitions_return_400_bad_request(self):
        incident = make_incident(self.resident, self.cat)
        auth_client(self.client, self.admin)

        # Try OPEN -> RESOLVED directly (invalid)
        url = f"/api/sos/incidents/{incident.id}/status/"
        res = self.client.post(url, {"status": "RESOLVED"}, format="json")
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(res.data["success"])

        # Transition to ACTIVE -> RESOLVED -> CLOSED
        self.client.post(url, {"status": "ACTIVE"}, format="json")
        self.client.post(url, {"status": "RESOLVED"}, format="json")
        url_closure = f"/api/sos/incidents/{incident.id}/closure/"
        self.client.post(url_closure, {"resolution_summary": "Done", "closure_reason": "Complete"}, format="json")

        # Now CLOSED -> ACTIVE (invalid, terminal state)
        res_after = self.client.post(url, {"status": "ACTIVE"}, format="json")
        self.assertEqual(res_after.status_code, status.HTTP_400_BAD_REQUEST)

    def test_resident_cannot_change_status_returns_403(self):
        incident = make_incident(self.resident, self.cat)
        auth_client(self.client, self.resident)

        url = f"/api/sos/incidents/{incident.id}/status/"
        res = self.client.post(url, {"status": "ACTIVE"}, format="json")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_timeline_api_returns_structured_lifecycle(self):
        incident = make_incident(self.resident, self.cat)
        auth_client(self.client, self.admin)

        url_status = f"/api/sos/incidents/{incident.id}/status/"
        self.client.post(url_status, {"status": "ACTIVE", "remarks": "Responder on site"}, format="json")

        url_timeline = f"/api/sos/incidents/{incident.id}/timeline/"
        res = self.client.get(url_timeline)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["success"])
        timeline = res.data["timeline"]
        self.assertGreaterEqual(len(timeline), 2)
        self.assertEqual(timeline[0]["status"], "OPEN")
        self.assertEqual(timeline[-1]["status"], "ACTIVE")


class Day16EmergencyChatTest(APITestCase):
    def setUp(self):
        self.cat = make_category("Medical Emergency")
        self.resident = make_user("res_d16@test.com", role="RESIDENT", full_name="Resident D16")
        self.volunteer = make_user("vol_d16@test.com", role="VOLUNTEER", full_name="Volunteer D16")
        self.admin = make_user("admin_d16@test.com", role="ADMIN", full_name="Admin D16")
        self.unauthorized_resident = make_user("other_d16@test.com", role="RESIDENT", full_name="Other Resident")

        self.incident = SOSIncident.objects.create(
            resident=self.resident,
            category=self.cat,
            status="Pending",
            current_status="OPEN",
            latitude=Decimal("12.9716"),
            longitude=Decimal("77.5946")
        )

    def test_chat_message_creation_and_retrieval(self):
        auth_client(self.client, self.resident)
        url = f"/api/sos/incidents/{self.incident.id}/chat/"

        res = self.client.post(url, {"message": "Please help, I fell down!", "message_type": "TEXT"})
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(res.data["success"])
        self.assertEqual(res.data["message"]["sender_role"], "RESIDENT")
        self.assertEqual(res.data["message"]["message"], "Please help, I fell down!")

        res_history = self.client.get(url)
        self.assertEqual(res_history.status_code, status.HTTP_200_OK)
        results = res_history.data.get("results", [])
        self.assertGreaterEqual(len(results), 1)

    def test_system_messages_generated_on_lifecycle(self):
        auth_client(self.client, self.admin)

        url_status = f"/api/sos/incidents/{self.incident.id}/status/"
        self.client.post(url_status, {"status": "ACTIVE"}, format="json")

        url_chat = f"/api/sos/incidents/{self.incident.id}/chat/"
        res = self.client.get(url_chat)
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        messages = res.data.get("results", [])
        system_msgs = [m for m in messages if m["message_type"] == "SYSTEM"]
        self.assertGreaterEqual(len(system_msgs), 1)
        self.assertTrue(any("ACTIVE" in m["message"] or "triggered" in m["message"] for m in system_msgs))

    def test_unauthorized_user_blocked_from_chat(self):
        auth_client(self.client, self.unauthorized_resident)
        url = f"/api/sos/incidents/{self.incident.id}/chat/"

        res_get = self.client.get(url)
        self.assertEqual(res_get.status_code, status.HTTP_403_FORBIDDEN)

        res_post = self.client.post(url, {"message": "Hacker msg"})
        self.assertEqual(res_post.status_code, status.HTTP_403_FORBIDDEN)

    def test_closed_incident_chat_is_read_only(self):
        auth_client(self.client, self.admin)
        url_status = f"/api/sos/incidents/{self.incident.id}/status/"
        self.client.post(url_status, {"status": "ACTIVE"}, format="json")
        self.client.post(url_status, {"status": "RESOLVED"}, format="json")

        url_closure = f"/api/sos/incidents/{self.incident.id}/closure/"
        self.client.post(url_closure, {"resolution_summary": "Done", "closure_reason": "Resolved"}, format="json")

        url_chat = f"/api/sos/incidents/{self.incident.id}/chat/"
        res_post = self.client.post(url_chat, {"message": "New message after close"})
        self.assertEqual(res_post.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("read-only", res_post.data["error"])

    def test_chat_search_and_filtering(self):
        auth_client(self.client, self.resident)
        url = f"/api/sos/incidents/{self.incident.id}/chat/"
        self.client.post(url, {"message": "Specific keyword banana", "message_type": "TEXT"})
        self.client.post(url, {"message": "Another message apple", "message_type": "TEXT"})

        res_search = self.client.get(f"{url}?search=banana")
        self.assertEqual(res_search.status_code, status.HTTP_200_OK)
        results = res_search.data.get("results", [])
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["message"], "Specific keyword banana")


class Day17DirectoryAndFeedTest(APITestCase):
    def setUp(self):
        from society.models import Society
        from accounts.models import ResidentProfile, UserDirectoryProfile

        self.society_a = Society.objects.create(name="Green Park Society", code="GPS01", address="Bangalore")
        self.society_b = Society.objects.create(name="Blue Sky Society", code="BSS02", address="Mumbai")

        self.cat = make_category("Fire Emergency")

        self.resident_a = make_user("res_a@test.com", role="RESIDENT", full_name="Resident A", phone_number="+919876543210")
        ResidentProfile.objects.create(user=self.resident_a, society=self.society_a, status="Approved")
        UserDirectoryProfile.objects.create(user=self.resident_a, visibility="PUBLIC", is_available=True)

        self.volunteer_a = make_user("vol_a@test.com", role="VOLUNTEER", full_name="Volunteer A", phone_number="+919876543211")
        ResidentProfile.objects.create(user=self.volunteer_a, society=self.society_a, status="Approved")
        UserDirectoryProfile.objects.create(user=self.volunteer_a, visibility="RESPONDERS", is_available=True)

        self.resident_b = make_user("res_b@test.com", role="RESIDENT", full_name="Resident B", phone_number="+919876543212")
        ResidentProfile.objects.create(user=self.resident_b, society=self.society_b, status="Approved")

        self.admin = make_user("admin_d17@test.com", role="ADMIN", full_name="Admin D17")

        self.incident = SOSIncident.objects.create(
            resident=self.resident_a,
            category=self.cat,
            status="Pending",
            current_status="OPEN",
            latitude=Decimal("12.9716"),
            longitude=Decimal("77.5946")
        )

    def test_contact_directory_society_isolation_and_privacy_masking(self):
        auth_client(self.client, self.resident_a)
        res = self.client.get("/api/directory/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        contacts = res.data.get("results", [])

        contact_ids = [c["id"] for c in contacts]
        self.assertIn(self.resident_a.id, contact_ids)
        self.assertIn(self.volunteer_a.id, contact_ids)
        self.assertNotIn(self.resident_b.id, contact_ids)

        vol_contact = next(c for c in contacts if c["id"] == self.volunteer_a.id)
        self.assertTrue(vol_contact["is_masked"])
        self.assertIn("****", vol_contact["phone_number"])

        auth_client(self.client, self.volunteer_a)
        res_vol = self.client.get("/api/directory/")
        contacts_vol = res_vol.data.get("results", [])
        vol_contact_as_responder = next(c for c in contacts_vol if c["id"] == self.volunteer_a.id)
        self.assertFalse(vol_contact_as_responder["is_masked"])
        self.assertEqual(vol_contact_as_responder["phone_number"], "+919876543211")

    def test_incident_response_updates_creation_and_feed(self):
        auth_client(self.client, self.resident_a)
        url = f"/api/sos/incidents/{self.incident.id}/updates/"

        res = self.client.post(url, {
            "message": "Fire brigade has been called!",
            "update_type": "SECURITY",
            "visibility": "PUBLIC"
        })
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(res.data["success"])
        self.assertEqual(res.data["update"]["update_type"], "SECURITY")

        res_feed = self.client.get(url)
        self.assertEqual(res_feed.status_code, status.HTTP_200_OK)
        results = res_feed.data.get("results", [])
        self.assertGreaterEqual(len(results), 1)

    def test_closed_incident_response_updates_read_only(self):
        auth_client(self.client, self.admin)
        url_status = f"/api/sos/incidents/{self.incident.id}/status/"
        self.client.post(url_status, {"status": "ACTIVE"}, format="json")
        self.client.post(url_status, {"status": "RESOLVED"}, format="json")

        url_closure = f"/api/sos/incidents/{self.incident.id}/closure/"
        self.client.post(url_closure, {"resolution_summary": "Done", "closure_reason": "Resolved"}, format="json")

        url_updates = f"/api/sos/incidents/{self.incident.id}/updates/"
        res_post = self.client.post(url_updates, {"message": "Update after close"})
        self.assertEqual(res_post.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("read-only", res_post.data["error"])


class Day18SecurityDashboardTest(APITestCase):
    def setUp(self):
        from society.models import Society
        from accounts.models import ResidentProfile

        self.society = Society.objects.create(name="Security Test Society", code="SEC01", address="Chennai")
        self.cat = make_category("Medical Emergency")

        self.resident = make_user("res_sec@test.com", role="RESIDENT", full_name="Sec Resident", phone_number="+919876543220")
        ResidentProfile.objects.create(user=self.resident, society=self.society, status="Approved")

        self.security_user = make_user("sec_officer@test.com", role="SECURITY", full_name="Officer Ramesh", phone_number="+919876543221")
        ResidentProfile.objects.create(user=self.security_user, society=self.society, status="Approved")

        self.incident = SOSIncident.objects.create(
            resident=self.resident,
            category=self.cat,
            status="Pending",
            current_status="OPEN",
            latitude=Decimal("13.0827"),
            longitude=Decimal("80.2707")
        )

    def test_security_dashboard_summary_api(self):
        auth_client(self.client, self.security_user)
        res = self.client.get("/api/security/dashboard/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["success"])
        summary = res.data.get("summary", {})
        self.assertIn("active_incidents", summary)
        self.assertGreaterEqual(summary["active_incidents"], 1)

    def test_security_incidents_list_api(self):
        auth_client(self.client, self.security_user)
        res = self.client.get("/api/security/incidents/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        results = res.data.get("results", [])
        self.assertGreaterEqual(len(results), 1)

    def test_security_incident_resolution_api(self):
        auth_client(self.client, self.security_user)
        url = f"/api/security/incidents/{self.incident.id}/resolution/"

        res = self.client.post(url, {
            "resolution_summary": "Ambulance arrived and patient stabilized.",
            "actions_taken": "First aid provided, escorted to hospital.",
            "medical_assistance": "true",
            "police_assistance": "false",
            "fire_assistance": "false",
            "property_damage": "false",
            "casualties": 0
        })
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["success"])

        self.incident.refresh_from_db()
        self.assertEqual(self.incident.current_status, "RESOLVED")

    def test_security_reporting_summary_api(self):
        auth_client(self.client, self.security_user)
        res = self.client.get("/api/security/reports/summary/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["success"])
        reporting = res.data.get("reporting", {})
        self.assertIn("today_incidents_count", reporting)
        self.assertIn("response_success_rate", reporting)


class GuardianSOSWorkflowTest(APITestCase):
    def setUp(self):
        from emergency.models import ResidentGuardian
        self.cat = make_category("Medical SOS")

        # Resident A (Ward)
        self.resident_a = make_user("resident_a@test.com", role="RESIDENT", full_name="Resident Alice", phone_number="+919000000001")
        # Resident B (Linked Guardian)
        self.resident_b = make_user("resident_b@test.com", role="RESIDENT", full_name="Guardian Bob", phone_number="+919000000002")
        # Resident C (Unlinked stranger resident)
        self.resident_c = make_user("resident_c@test.com", role="RESIDENT", full_name="Resident Charlie", phone_number="+919000000003")

        # Link Resident B as Primary Guardian for Resident A
        self.link = ResidentGuardian.objects.create(
            resident=self.resident_a,
            guardian=self.resident_b,
            is_primary=True,
            status='Active'
        )

    def test_guardian_sos_trigger_dashboard_and_accept_workflow(self):
        # 1. Resident A triggers SOS
        auth_client(self.client, self.resident_a)
        res_sos = self.client.post("/api/emergency/alerts/", {
            "category": "Medical SOS",
            "message": "Chest pain, need help!",
            "latitude": 12.9716,
            "longitude": 77.5946,
        })
        self.assertEqual(res_sos.status_code, status.HTTP_201_CREATED)
        incident_id = res_sos.data["incident"]["id"]

        # 2. Guardian (Resident B) views Guardian Dashboard
        auth_client(self.client, self.resident_b)
        res_dash = self.client.get("/api/guardian/dashboard/")
        self.assertEqual(res_dash.status_code, status.HTTP_200_OK)
        active_alerts = res_dash.data.get("active_alerts", [])
        self.assertEqual(len(active_alerts), 1)
        self.assertEqual(active_alerts[0]["id"], incident_id)
        self.assertEqual(active_alerts[0]["resident_name"], "Resident Alice")

        # 3. Unlinked stranger (Resident C) tries to accept -> HTTP 403
        auth_client(self.client, self.resident_c)
        res_unauth_accept = self.client.post(f"/api/sos/incidents/{incident_id}/accept/")
        self.assertEqual(res_unauth_accept.status_code, status.HTTP_403_FORBIDDEN)

        # 4. Linked Guardian (Resident B) accepts SOS
        auth_client(self.client, self.resident_b)
        res_accept = self.client.post(f"/api/sos/incidents/{incident_id}/accept/")
        self.assertEqual(res_accept.status_code, status.HTTP_200_OK)
        self.assertTrue(res_accept.data.get("success"))
        self.assertEqual(res_accept.data.get("assigned_to"), "Guardian Bob")

        # Verify DB status
        inc = SOSIncident.objects.get(id=incident_id)
        self.assertEqual(inc.status, "Accepted")
        self.assertEqual(inc.assigned_responder, self.resident_b)
        self.assertEqual(inc.assigned_role, "Guardian")

        # Verify notification sent to Resident A
        notif = Notification.objects.filter(user=self.resident_a, category="sos").order_by('-created_at').first()
        self.assertIsNotNone(notif)
        self.assertIn("Guardian Bob", notif.message)

    def test_guardian_sos_rejection_and_escalation_workflow(self):
        # 1. Resident A triggers SOS
        auth_client(self.client, self.resident_a)
        res_sos = self.client.post("/api/emergency/alerts/", {
            "category": "Medical SOS",
            "message": "Fainted in corridor!",
        })
        incident_id = res_sos.data["incident"]["id"]

        # 2. Linked Guardian (Resident B) rejects SOS with reason
        auth_client(self.client, self.resident_b)
        res_reject = self.client.post(f"/api/sos/incidents/{incident_id}/reject/", {
            "reason": "Out of city, cannot reach in time"
        }, format="json")
        self.assertEqual(res_reject.status_code, status.HTTP_200_OK)

class IncidentPermissionsWorkflowTest(APITestCase):
    def setUp(self):
        from emergency.models import ResidentGuardian
        self.cat = make_category("Emergency")

        # John and Alice are residents.
        # John has selected Alice as his primary guardian.
        self.john = make_user("john@test.com", role="RESIDENT", full_name="John")
        self.alice = make_user("alice@test.com", role="RESIDENT", full_name="Alice")

        # Link Alice as primary guardian for John
        ResidentGuardian.objects.create(
            resident=self.john,
            guardian=self.alice,
            is_primary=True,
            status='Active'
        )

    def test_scenario_1_john_triggers_sos(self):
        """
        Scenario 1: John presses SOS button.
        John (Sender): is_sender=True, responder permissions all False.
        Alice (Guardian): is_sender=False, is_assigned_guardian=True, can_accept=True, can_decline=True, can_chat=True, can_call=True, can_navigate=True.
        """
        auth_client(self.client, self.john)
        res = self.client.post("/api/emergency/alerts/", {
            "category": "Emergency",
            "message": "John needs help",
        })
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        incident_id = res.data["incident"]["id"]

        # 1. John (Sender) fetches incident details
        auth_client(self.client, self.john)
        john_view = self.client.get(f"/api/sos/incidents/{incident_id}/")
        self.assertEqual(john_view.status_code, status.HTTP_200_OK)
        self.assertTrue(john_view.data["is_sender"])
        self.assertFalse(john_view.data["is_assigned_guardian"])
        self.assertFalse(john_view.data["can_accept"])
        self.assertFalse(john_view.data["can_decline"])
        self.assertFalse(john_view.data["can_chat"])
        self.assertFalse(john_view.data["can_call"])
        self.assertFalse(john_view.data["can_navigate"])

        # 2. Alice (Guardian) fetches incident details
        auth_client(self.client, self.alice)
        alice_view = self.client.get(f"/api/sos/incidents/{incident_id}/")
        self.assertEqual(alice_view.status_code, status.HTTP_200_OK)
        self.assertFalse(alice_view.data["is_sender"])
        self.assertTrue(alice_view.data["is_assigned_guardian"])
        self.assertTrue(alice_view.data["can_accept"])
        self.assertTrue(alice_view.data["can_decline"])
        self.assertTrue(alice_view.data["can_chat"])
        self.assertTrue(alice_view.data["can_call"])
        self.assertTrue(alice_view.data["can_navigate"])

    def test_scenario_2_alice_triggers_sos_and_john_is_guardian(self):
        """
        Scenario 2: John links Alice as John's guardian, and John is linked as Alice's guardian.
        Alice triggers SOS -> Alice (Sender) gets is_sender=True, responder permissions False.
        John (Guardian for Alice) gets is_sender=False, is_assigned_guardian=True, responder permissions True.
        """
        from emergency.models import ResidentGuardian
        # Link John as guardian for Alice as well
        ResidentGuardian.objects.create(
            resident=self.alice,
            guardian=self.john,
            is_primary=True,
            status='Active'
        )

        # Alice triggers SOS
        auth_client(self.client, self.alice)
        res = self.client.post("/api/emergency/alerts/", {
            "category": "Emergency",
            "message": "Alice needs help",
        })
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        incident_id = res.data["incident"]["id"]

        # Alice (Sender) fetches incident details
        auth_client(self.client, self.alice)
        alice_view = self.client.get(f"/api/sos/incidents/{incident_id}/")
        self.assertEqual(alice_view.status_code, status.HTTP_200_OK)
        self.assertTrue(alice_view.data["is_sender"])
        self.assertFalse(alice_view.data["can_accept"])
        self.assertFalse(alice_view.data["can_decline"])
        self.assertFalse(alice_view.data["can_chat"])
        self.assertFalse(alice_view.data["can_call"])
        self.assertFalse(alice_view.data["can_navigate"])

        # John (Guardian for Alice) fetches incident details
        auth_client(self.client, self.john)
        john_view = self.client.get(f"/api/sos/incidents/{incident_id}/")
        self.assertEqual(john_view.status_code, status.HTTP_200_OK)
        self.assertFalse(john_view.data["is_sender"])
        self.assertTrue(john_view.data["is_assigned_guardian"])
        self.assertTrue(john_view.data["can_accept"])
        self.assertTrue(john_view.data["can_decline"])
        self.assertTrue(john_view.data["can_chat"])
        self.assertTrue(john_view.data["can_call"])
        self.assertTrue(john_view.data["can_navigate"])


class Day12CommunityBroadcastTest(APITestCase):
    def setUp(self):
        self.resident = make_user("resident_d12@test.com", role="RESIDENT")
        self.volunteer_near = make_user("vol_near@test.com", role="VOLUNTEER")
        self.volunteer_far = make_user("vol_far@test.com", role="VOLUNTEER")
        self.security = make_user("sec_d12@test.com", role="SECURITY")
        self.category = make_category("Day12 Emergency")

        from accounts.models import VolunteerProfile, SecurityProfile
        VolunteerProfile.objects.create(
            user=self.volunteer_near,
            is_online=True,
            availability_status="ONLINE",
            status="Approved",
            latitude=12.9716,
            longitude=77.5946,
            visibility_radius=5000.0
        )

        VolunteerProfile.objects.create(
            user=self.volunteer_far,
            is_online=True,
            availability_status="ONLINE",
            status="Approved",
            latitude=15.0000,  # ~225 km away
            longitude=77.5946,
            visibility_radius=5000.0
        )

        SecurityProfile.objects.create(
            user=self.security,
            is_on_duty=True,
            duty_status="AVAILABLE",
            employment_status="Active",
            latitude=12.9720,
            longitude=77.5950
        )

        self.incident = SOSIncident.objects.create(
            resident=self.resident,
            category=self.category,
            message="Day 12 Broadcast SOS",
            latitude=12.9716,
            longitude=77.5946,
            priority="CRITICAL"
        )

    def test_volunteer_availability_api(self):
        auth_client(self.client, self.volunteer_near)
        url = reverse("volunteer_availability")
        res = self.client.patch(url, {"availability_status": "ONLINE", "is_online": True})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["availability_status"], "ONLINE")

    def test_security_availability_api(self):
        auth_client(self.client, self.security)
        url = reverse("security_availability")
        res = self.client.patch(url, {"duty_status": "AVAILABLE", "is_on_duty": True})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["duty_status"], "AVAILABLE")

    def test_community_broadcast_radius_filtering(self):
        auth_client(self.client, self.resident)
        url = reverse("sos-community-broadcast")
        res = self.client.post(url, {
            "incident_id": self.incident.id,
            "target_role": "ALL",
            "radius_km": 5.0
        })
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["success"])
        # Nearby volunteer & Security notified (2 total)
        self.assertEqual(res.data["total_notified"], 2)

    def test_broadcast_logs_api(self):
        auth_client(self.client, self.resident)
        self.client.post(reverse("sos-community-broadcast"), {
            "incident_id": self.incident.id,
            "target_role": "VOLUNTEER",
            "radius_km": 5.0
        })
        logs_res = self.client.get(reverse("sos-broadcast-logs"))
        self.assertEqual(logs_res.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(logs_res.data["count"], 1)


class Day13AnalyticsAndMonitoringTest(APITestCase):
    """
    Test suite for Day 13 Alert Monitoring Dashboard & Analytics endpoints.
    """
    def setUp(self):
        self.admin = make_user("admin_day13@careconnect.com", role="ADMIN")
        self.resident = make_user("res_day13@careconnect.com", role="RESIDENT")
        self.category = make_category("Medical Emergency")
        self.incident = make_incident(self.resident, self.category, status_val="Pending")

    def test_dashboard_summary_api(self):
        auth_client(self.client, self.admin)
        res = self.client.get(reverse("sos-dashboard-summary"))
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["success"])
        self.assertIn("kpis", res.data)
        self.assertIn("charts", res.data)

    def test_alert_status_tracking_api(self):
        auth_client(self.client, self.admin)
        res = self.client.get(reverse("sos-alert-status-tracking"))
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("results", res.data)

        inc_res = self.client.get(reverse("sos-incident-status-tracking", kwargs={"pk": self.incident.id}))
        self.assertEqual(inc_res.status_code, status.HTTP_200_OK)
        self.assertEqual(inc_res.data["incident_id"], self.incident.id)

    def test_notification_delivery_tracking_api(self):
        auth_client(self.client, self.admin)
        res = self.client.get(reverse("sos-notification-delivery-tracking"))
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("total_notifications", res.data)

    def test_response_monitoring_api(self):
        auth_client(self.client, self.admin)
        res = self.client.get(reverse("sos-response-monitoring"))
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("guardian_response_time", res.data)
        self.assertIn("security_response_time", res.data)
        self.assertIn("volunteer_response_time", res.data)


class Day14IncidentAcceptanceTest(APITestCase):
    """
    Test suite for Day 14 — Incident Acceptance Workflow & Responder Assignment.
    Covers:
      - Volunteer acceptance
      - Security staff acceptance
      - Duplicate acceptance conflict (409 Conflict)
      - Unauthorized responder prevention
      - Notification dispatch on responder assignment
    """
    def setUp(self):
        self.resident = make_user("resident_d14@careconnect.com", role="RESIDENT")
        self.volunteer1 = make_user("volunteer1_d14@careconnect.com", role="VOLUNTEER")
        self.volunteer2 = make_user("volunteer2_d14@careconnect.com", role="VOLUNTEER")
        self.security = make_user("security_d14@careconnect.com", role="SECURITY")
        self.regular_user = make_user("regular_d14@careconnect.com", role="RESIDENT")
        self.category = make_category("Fire Safety")
        self.incident = make_incident(self.resident, self.category, status_val="Pending")

    def test_volunteer_accept_incident_success(self):
        auth_client(self.client, self.volunteer1)
        url = reverse("sos-incident-accept-post", kwargs={"pk": self.incident.id})
        res = self.client.post(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["success"])
        self.assertEqual(res.data["status"], "Accepted")
        self.incident.refresh_from_db()
        self.assertEqual(self.incident.assigned_responder, self.volunteer1)
        self.assertEqual(self.incident.assignment_status, "Assigned")

    def test_security_accept_incident_success(self):
        auth_client(self.client, self.security)
        url = reverse("sos-incident-accept-post", kwargs={"pk": self.incident.id})
        res = self.client.post(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["success"])
        self.incident.refresh_from_db()
        self.assertEqual(self.incident.assigned_responder, self.security)

    def test_duplicate_acceptance_returns_409_conflict(self):
        # Volunteer 1 accepts first
        auth_client(self.client, self.volunteer1)
        url = reverse("sos-incident-accept-post", kwargs={"pk": self.incident.id})
        res1 = self.client.post(url)
        self.assertEqual(res1.status_code, status.HTTP_200_OK)

        # Volunteer 2 attempts to accept same incident
        auth_client(self.client, self.volunteer2)
        res2 = self.client.post(url)
        self.assertEqual(res2.status_code, status.HTTP_409_CONFLICT)
        self.assertFalse(res2.data["success"])
        self.assertIn("already", res2.data["detail"].lower())

    def test_unauthorized_user_cannot_accept_incident(self):
        auth_client(self.client, self.regular_user)
        url = reverse("sos-incident-accept-post", kwargs={"pk": self.incident.id})
        res = self.client.post(url)
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_assignment_notifications_dispatched(self):
        auth_client(self.client, self.volunteer1)
        url = reverse("sos-incident-accept-post", kwargs={"pk": self.incident.id})
        res = self.client.post(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        
        # Verify notification was dispatched to resident
        notif_exists = Notification.objects.filter(
            user=self.resident,
            title__icontains="Accepted"
        ).exists()
        self.assertTrue(notif_exists)


class Day16EmergencyChatTest(APITestCase):
    """
    Test suite for Day 16 — Emergency Chat Module.
    Covers:
      - Authorized chat message creation (Resident, Responder, Admin)
      - Unauthorized user access restriction (403 Forbidden)
      - Chat history retrieval with pagination
      - System message creation on incident lifecycle transitions
      - Closed incident chat locking (read-only mode)
      - Message soft deletion
    """
    def setUp(self):
        self.resident = make_user("resident_d16@careconnect.com", role="RESIDENT")
        self.responder = make_user("volunteer_d16@careconnect.com", role="VOLUNTEER")
        self.admin = make_user("admin_d16@careconnect.com", role="ADMIN")
        self.unauthorized_user = make_user("stranger_d16@careconnect.com", role="RESIDENT")

        self.category = make_category("Medical Emergency")
        self.incident = make_incident(self.resident, self.category, status_val="Pending")

        # Assign responder to incident
        self.incident.assigned_responder = self.responder
        self.incident.assigned_role = "VOLUNTEER"
        self.incident.current_status = "ACTIVE"
        self.incident.status = "In Progress"
        self.incident.save()

    def test_resident_send_chat_message_success(self):
        auth_client(self.client, self.resident)
        url = reverse("sos-chat", kwargs={"pk": self.incident.id})
        res = self.client.post(url, data={"message": "I need medical help immediately!", "message_type": "TEXT"})
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(res.data["success"])
        self.assertEqual(res.data["message"]["sender_role"], "RESIDENT")
        self.assertEqual(res.data["message"]["message"], "I need medical help immediately!")

    def test_responder_send_chat_message_success(self):
        auth_client(self.client, self.responder)
        url = reverse("sos-chat", kwargs={"pk": self.incident.id})
        res = self.client.post(url, data={"message": "On my way with first aid kit.", "message_type": "TEXT"})
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(res.data["success"])
        self.assertEqual(res.data["message"]["sender_role"], "VOLUNTEER")

    def test_unauthorized_user_chat_access_forbidden(self):
        auth_client(self.client, self.unauthorized_user)
        url = reverse("sos-chat", kwargs={"pk": self.incident.id})

        # GET history forbidden
        res_get = self.client.get(url)
        self.assertEqual(res_get.status_code, status.HTTP_403_FORBIDDEN)

        # POST message forbidden
        res_post = self.client.post(url, data={"message": "Hacking chat", "message_type": "TEXT"})
        self.assertEqual(res_post.status_code, status.HTTP_403_FORBIDDEN)

    def test_chat_history_pagination(self):
        auth_client(self.client, self.resident)
        url = reverse("sos-chat", kwargs={"pk": self.incident.id})

        # Send multiple messages
        for i in range(5):
            self.client.post(url, data={"message": f"Test message {i+1}", "message_type": "TEXT"})

        res = self.client.get(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data["results"]), 5)

    def test_closed_incident_chat_locking(self):
        # Close the incident
        self.incident.current_status = "CLOSED"
        self.incident.status = "Closed"
        self.incident.save()

        auth_client(self.client, self.resident)
        url = reverse("sos-chat", kwargs={"pk": self.incident.id})

        # History should still be readable
        res_get = self.client.get(url)
        self.assertEqual(res_get.status_code, status.HTTP_200_OK)

        # New messages must be rejected
        res_post = self.client.post(url, data={"message": "Is anyone there?", "message_type": "TEXT"})
        self.assertEqual(res_post.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("read-only", res_post.data["error"].lower())

    def test_message_soft_deletion(self):
        auth_client(self.client, self.resident)
        url_chat = reverse("sos-chat", kwargs={"pk": self.incident.id})
        res_create = self.client.post(url_chat, data={"message": "Accidental text", "message_type": "TEXT"})
        msg_id = res_create.data["message"]["id"]

        url_delete = reverse("sos-chat-detail", kwargs={"pk": self.incident.id, "message_id": msg_id})
        res_del = self.client.delete(url_delete)
        self.assertEqual(res_del.status_code, status.HTTP_200_OK)
        self.assertTrue(res_del.data["success"])


class Day17ContactDirectoryAndUpdatesTest(APITestCase):
    """
    Comprehensive test suite for Day 17 — Contact Directory & Response Updates.
    Covers:
      - Society contact directory listing and role filtering
      - Society isolation privacy enforcement (cross-society block)
      - Phone and email masking for unauthorized viewers
      - Response update feed generation during incident lifecycle transitions
      - Response update authorization and security (403 Forbidden on unauthorized access)
    """
    def setUp(self):
        from society.models import Society, BlockTower, Flat
        from accounts.models import ResidentProfile, UserDirectoryProfile

        # Create Society A and Society B
        self.society_a = Society.objects.create(name="Greenwood Heights", address="123 Park Ave")
        self.society_b = Society.objects.create(name="Oceanic Towers", address="456 Beach Rd")

        self.block_a = BlockTower.objects.create(society=self.society_a, name="Block A")
        self.block_b = BlockTower.objects.create(society=self.society_b, name="Block B")

        self.flat_a = Flat.objects.create(block=self.block_a, flat_number="101")
        self.flat_b = Flat.objects.create(block=self.block_b, flat_number="202")

        # Create Users in Society A
        self.resident_a = make_user("resident_a@societya.com", role="RESIDENT", full_name="Vivek Kumar")
        ResidentProfile.objects.create(user=self.resident_a, society=self.society_a, block=self.block_a, flat=self.flat_a)
        UserDirectoryProfile.objects.create(user=self.resident_a, visibility="PUBLIC", is_available=True)

        self.volunteer_a = make_user("volunteer_a@societya.com", role="VOLUNTEER", full_name="Rahul Volunteer")
        ResidentProfile.objects.create(user=self.volunteer_a, society=self.society_a, block=self.block_a, flat=self.flat_a)
        UserDirectoryProfile.objects.create(user=self.volunteer_a, visibility="PUBLIC", is_available=True)

        self.security_a = make_user("security_a@societya.com", role="SECURITY", full_name="Suresh Guard")
        ResidentProfile.objects.create(user=self.security_a, society=self.society_a, block=self.block_a, flat=self.flat_a)
        UserDirectoryProfile.objects.create(user=self.security_a, visibility="RESPONDERS", is_available=True)

        # Create User in Society B
        self.resident_b = make_user("resident_b@societyb.com", role="RESIDENT", full_name="Stranger User")
        ResidentProfile.objects.create(user=self.resident_b, society=self.society_b, block=self.block_b, flat=self.flat_b)
        UserDirectoryProfile.objects.create(user=self.resident_b, visibility="PUBLIC", is_available=True)

        self.category = make_category("Fire Alarm")
        self.incident = make_incident(self.resident_a, self.category, status_val="Pending")

    def test_directory_society_scoped_results(self):
        auth_client(self.client, self.resident_a)
        url = reverse("direct-contact-directory")
        res = self.client.get(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        # Should only contain users from Society A
        user_ids = [item["id"] for item in res.data["results"]]
        self.assertIn(self.resident_a.id, user_ids)
        self.assertIn(self.volunteer_a.id, user_ids)
        self.assertNotIn(self.resident_b.id, user_ids)

    def test_directory_privacy_masking_for_unauthorized_user(self):
        auth_client(self.client, self.resident_a)
        url = reverse("direct-contact-directory")
        res = self.client.get(url, data={"search": "Suresh Guard"})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data["results"]), 1)

        sec_data = res.data["results"][0]
        # Security visibility is RESPONDERS; resident_a is not a responder, so contact must be masked
        self.assertTrue(sec_data["is_masked"])
        self.assertIn("*", sec_data["phone_number"])

    def test_response_updates_feed_retrieval(self):
        from sos.services import IncidentResponseUpdateService
        IncidentResponseUpdateService.create_system_update(self.incident, "INCIDENT_CREATED", "Emergency incident created.")

        auth_client(self.client, self.resident_a)
        url = reverse("sos-updates", kwargs={"pk": self.incident.id})
        res = self.client.get(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(len(res.data["results"]) >= 1)
        self.assertEqual(res.data["results"][0]["update_type"], "INCIDENT_CREATED")

    def test_unauthorized_response_updates_access_forbidden(self):
        auth_client(self.client, self.resident_b)
        url = reverse("sos-updates", kwargs={"pk": self.incident.id})

        # GET forbidden for cross-society resident
        res_get = self.client.get(url)
        self.assertEqual(res_get.status_code, status.HTTP_403_FORBIDDEN)

        # POST forbidden for cross-society resident
        res_post = self.client.post(url, data={"message": "Hacking feed", "update_type": "NOTE"})
        self.assertEqual(res_post.status_code, status.HTTP_403_FORBIDDEN)


class Day18SecurityStaffDashboardTest(APITestCase):
    """
    Comprehensive test suite for Day 18 — Security Staff & Incident Dashboard Completion.
    Covers:
      - Security role authorization & 403 Forbidden for non-security staff
      - Society isolation enforcement (cross-society block)
      - Active incident list filtering & pagination
      - Security status updates (RESPONDING, ARRIVED, REQUEST_BACKUP)
      - Formal security incident resolution report & lifecycle transition
      - Security reporting summary calculations & date timeframe filters
    """
    def setUp(self):
        from society.models import Society, BlockTower, Flat
        from accounts.models import ResidentProfile, UserDirectoryProfile

        self.society_a = Society.objects.create(name="Apex Towers", address="1 Security Way")
        self.society_b = Society.objects.create(name="Horizon Vista", address="2 Ocean Blvd")

        self.block_a = BlockTower.objects.create(society=self.society_a, name="Block A")
        self.block_b = BlockTower.objects.create(society=self.society_b, name="Block B")

        self.flat_a = Flat.objects.create(block=self.block_a, flat_number="101")
        self.flat_b = Flat.objects.create(block=self.block_b, flat_number="202")

        # Society A users
        self.resident_a = make_user("resident_sec18_a@test.com", role="RESIDENT", full_name="Aarav Sharma")
        ResidentProfile.objects.create(user=self.resident_a, society=self.society_a, block=self.block_a, flat=self.flat_a)

        self.security_a = make_user("security_sec18_a@test.com", role="SECURITY", full_name="Officer Vikram")
        ResidentProfile.objects.create(user=self.security_a, society=self.society_a, block=self.block_a, flat=self.flat_a)
        UserDirectoryProfile.objects.create(user=self.security_a, visibility="RESPONDERS", is_available=True)

        # Society B users
        self.resident_b = make_user("resident_sec18_b@test.com", role="RESIDENT", full_name="Bhavya Patel")
        ResidentProfile.objects.create(user=self.resident_b, society=self.society_b, block=self.block_b, flat=self.flat_b)

        self.security_b = make_user("security_sec18_b@test.com", role="SECURITY", full_name="Officer Karan")
        ResidentProfile.objects.create(user=self.security_b, society=self.society_b, block=self.block_b, flat=self.flat_b)
        UserDirectoryProfile.objects.create(user=self.security_b, visibility="RESPONDERS", is_available=True)

        self.category = make_category("Security Threat")
        self.incident_a = make_incident(self.resident_a, self.category, status_val="Pending")
        self.incident_b = make_incident(self.resident_b, self.category, status_val="Pending")

    def test_security_dashboard_authorization(self):
        # Resident role -> 403 Forbidden
        auth_client(self.client, self.resident_a)
        res_res = self.client.get(reverse("security-dashboard-summary"))
        self.assertEqual(res_res.status_code, status.HTTP_403_FORBIDDEN)

        # Security role -> 200 OK
        auth_client(self.client, self.security_a)
        res_sec = self.client.get(reverse("security-dashboard-summary"))
        self.assertEqual(res_sec.status_code, status.HTTP_200_OK)
        self.assertIn("active_incidents", res_sec.data["summary"])

    def test_security_incidents_list_society_scoped(self):
        auth_client(self.client, self.security_a)
        res = self.client.get(reverse("security-incidents-list"))
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        ids = [item["id"] for item in res.data["results"]]
        self.assertIn(self.incident_a.id, ids)
        self.assertNotIn(self.incident_b.id, ids)

    def test_security_status_update_responding_and_arrived(self):
        auth_client(self.client, self.security_a)

        # Mark Responding
        url_status = reverse("security-incident-status", kwargs={"pk": self.incident_a.id})
        res_resp = self.client.post(url_status, data={"status": "RESPONDING"})
        self.assertEqual(res_resp.status_code, status.HTTP_200_OK)

        self.incident_a.refresh_from_db()
        self.assertEqual(self.incident_a.current_status, "ACTIVE")

        # Mark Arrived
        res_arr = self.client.post(url_status, data={"status": "ARRIVED"})
        self.assertEqual(res_arr.status_code, status.HTTP_200_OK)

    def test_security_formal_resolution_and_society_isolation(self):
        # Cross-society resolution attempt by Security B -> 403 Forbidden
        auth_client(self.client, self.security_b)
        url_res_a = reverse("security-incident-resolution", kwargs={"pk": self.incident_a.id})
        res_cross = self.client.post(url_res_a, data={"resolution_summary": "Cross society resolve attempt."})
        self.assertEqual(res_cross.status_code, status.HTTP_403_FORBIDDEN)

        # Authorized Security A resolution -> 200 OK
        auth_client(self.client, self.security_a)
        res_ok = self.client.post(url_res_a, data={
            "resolution_summary": "Intruder apprehend and handed to authorities.",
            "actions_taken": "Secured perimeter and verified gate access.",
            "police_assistance": "true"
        })
        self.assertEqual(res_ok.status_code, status.HTTP_200_OK)

        self.incident_a.refresh_from_db()
        self.assertEqual(self.incident_a.current_status, "RESOLVED")

    def test_security_reporting_summary_date_filters(self):
        auth_client(self.client, self.security_a)
        url_rep = reverse("security-reports-summary")
        res_rep = self.client.get(url_rep, data={"timeframe": "7days"})
        self.assertEqual(res_rep.status_code, status.HTTP_200_OK)
        self.assertTrue(res_rep.data["success"])
        self.assertIn("today_incidents_count", res_rep.data["reporting"])


class Day19ReportingAndAnalyticsTest(APITestCase):
    """
    Comprehensive test suite for Day 19 — Reporting Dashboards & Admin Portal Finalization.
    Covers:
      - Admin authorization checks for platform-wide reports export
      - Multi-parameter filtering (timeframe, society, category, priority, status)
      - KPI calculations & time-series chart aggregation
      - Native Excel (.xlsx) and PDF (.pdf) report file export generation
      - Zero-fallback calculations for empty datasets
    """
    def setUp(self):
        from society.models import Society, BlockTower, Flat
        from accounts.models import ResidentProfile

        self.society = Society.objects.create(name="Palm Grove Society", address="100 Analytics Way")
        self.block = BlockTower.objects.create(society=self.society, name="Tower A")
        self.flat = Flat.objects.create(block=self.block, flat_number="501")

        self.admin = make_user("admin_rep19@test.com", role="ADMIN", full_name="Admin Boss")
        self.resident = make_user("resident_rep19@test.com", role="RESIDENT", full_name="Resident Person")
        ResidentProfile.objects.create(user=self.resident, society=self.society, block=self.block, flat=self.flat)

        self.category_med = make_category("Medical Emergency")
        self.category_fire = make_category("Fire Danger")

        self.incident_med = make_incident(self.resident, self.category_med, status_val="Pending")
        self.incident_med.priority = "CRITICAL"
        self.incident_med.save()

        from django.utils import timezone

        self.incident_fire = make_incident(self.resident, self.category_fire, status_val="Resolved")
        self.incident_fire.priority = "HIGH"
        self.incident_fire.resolved_at = timezone.now()
        self.incident_fire.save()

    def test_reporting_admin_authorization_enforced(self):
        url_export = reverse("direct-report-download")

        # Resident access -> 403 Forbidden
        self.client.force_authenticate(user=self.resident)
        res_res = self.client.get(url_export, data={"type": "incidents", "format": "pdf"})
        self.assertEqual(res_res.status_code, status.HTTP_403_FORBIDDEN)

        # Admin access -> 200 OK
        self.client.force_authenticate(user=self.admin)
        res_admin = self.client.get(url_export, data={"type": "incidents", "format": "pdf"})
        self.assertEqual(res_admin.status_code, status.HTTP_200_OK)

    def test_dashboard_summary_multi_filter_support(self):
        self.client.force_authenticate(user=self.admin)
        url_summary = reverse("sos-dashboard-summary")

        # Filter by category
        res = self.client.get(url_summary, data={
            "timeframe": "30days",
            "society_id": self.society.id,
            "category": self.category_med.id,
            "priority": "CRITICAL"
        })
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["success"])
        self.assertEqual(res.data["kpis"]["total_incidents"], 1)

    def test_reporting_export_excel_and_pdf_formats(self):
        self.client.force_authenticate(user=self.admin)
        url_export = reverse("direct-report-download")

        # Test Excel (.xlsx) export
        res_excel = self.client.get(url_export, data={"type": "incidents", "format": "excel"})
        self.assertEqual(res_excel.status_code, status.HTTP_200_OK)
        self.assertEqual(res_excel.headers["Content-Type"], "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

        # Test PDF (.pdf) export
        res_pdf = self.client.get(url_export, data={"type": "incidents", "format": "pdf"})
        self.assertEqual(res_pdf.status_code, status.HTTP_200_OK)
        self.assertEqual(res_pdf.headers["Content-Type"], "application/pdf")

    def test_empty_dataset_returns_zeroes_cleanly(self):
        from society.models import Society
        empty_soc = Society.objects.create(name="Empty Society", address="0 Void St")

        self.client.force_authenticate(user=self.admin)
        url_summary = reverse("sos-dashboard-summary")
        res = self.client.get(url_summary, data={"society_id": empty_soc.id})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["kpis"]["total_incidents"], 0)
        self.assertEqual(res.data["kpis"]["resolution_rate"], 0.0)

















