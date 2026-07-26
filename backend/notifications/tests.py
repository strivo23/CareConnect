from django.test import TestCase
from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken

from notifications.models import Notification, FCMDevice, NotificationTemplate, NotificationLog, SMSLog
from notifications.dispatcher import NotificationDispatcher
from notifications.notification_service import (
    send_push,
    send_email,
    notify_guardians,
    SMSService,
)
from sos.models import SOSIncident, EmergencyCategory
from emergency.models import ResidentGuardian

User = get_user_model()


def auth_client(client, user):
    refresh = RefreshToken.for_user(user)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {refresh.access_token}")
    return client


class NotificationDispatcherTests(TestCase):
    def setUp(self):
        self.resident = User.objects.create_user(
            username="resident@test.com",
            email="resident@test.com",
            password="pass123",
            full_name="Resident Jane",
            role="RESIDENT",
            phone_number="+15550001",
            is_active=True
        )
        self.guardian = User.objects.create_user(
            username="guardian@test.com",
            email="guardian@test.com",
            password="pass123",
            full_name="Guardian John",
            role="RESIDENT",
            phone_number="+15550002",
            is_active=True
        )
        self.inactive_user = User.objects.create_user(
            username="inactive@test.com",
            email="inactive@test.com",
            password="pass123",
            full_name="Inactive User",
            role="RESIDENT",
            is_active=False
        )

        ResidentGuardian.objects.create(
            resident=self.resident,
            guardian=self.guardian,
            status='Active',
            is_primary=True
        )

        self.category = EmergencyCategory.objects.create(name="Medical Emergency", is_active=True)
        self.incident = SOSIncident.objects.create(
            resident=self.resident,
            category=self.category,
            message="Severe chest pains on 4th floor",
            address="Building A, Flat 402, CareConnect Heights",
            priority="CRITICAL"
        )

    def test_dispatcher_sos_created_routing_and_audit_logs(self):
        summary = NotificationDispatcher.dispatch_sos_created(self.incident)
        self.assertEqual(summary['resident'], 1)
        self.assertEqual(summary['guardians'], 1)

        # Check in-app notification created for resident and guardian
        res_notif = Notification.objects.filter(user=self.resident).first()
        self.assertIsNotNone(res_notif)
        self.assertEqual(res_notif.priority, "CRITICAL")
        self.assertEqual(res_notif.notification_type, "SOS_CREATED")

        g_notif = Notification.objects.filter(user=self.guardian).first()
        self.assertIsNotNone(g_notif)

        # Check audit log entries created
        self.assertTrue(NotificationLog.objects.filter(channel='IN_APP', status='SUCCESS').exists())

    def test_dispatcher_skips_inactive_users(self):
        # Attempt to dispatch to inactive user
        notifs = NotificationDispatcher._dispatch_to_user(
            user=self.inactive_user,
            title="Test Title",
            message="Test Message"
        )
        self.assertEqual(len(notifs), 0)
        # Check audit log recorded failure/skip
        self.assertTrue(NotificationLog.objects.filter(channel='SKIPPED', status='FAILURE').exists())

    def test_dispatcher_guardian_response(self):
        summary = NotificationDispatcher.dispatch_guardian_response(self.incident, self.guardian, 'Accepted')
        self.assertEqual(summary['resident'], 1)
        self.assertTrue(Notification.objects.filter(user=self.resident, notification_type='GUARDIAN_RESPONSE').exists())


class NotificationAPITests(APITestCase):
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
        auth_client(self.client, self.user1)

        # Create notifications for user1
        self.notif1 = Notification.objects.create(
            user=self.user1,
            title="User 1 Alert",
            message="Alert message 1",
            is_read=False
        )
        # Create notification for user2
        self.notif2 = Notification.objects.create(
            user=self.user2,
            title="User 2 Alert",
            message="Alert message 2",
            is_read=False
        )

    def test_list_notifications_pagination_and_scoping(self):
        url = reverse("notification-list")
        res = self.client.get(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        # User 1 should see only user 1 notification
        results = res.data.get('results', res.data)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['id'], self.notif1.id)

    def test_unread_count_api(self):
        url = reverse("notification-count")
        res = self.client.get(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['unread_count'], 1)

    def test_mark_read_ownership_security_validation(self):
        # User 1 tries to mark User 2 notification read -> Should return 403 Forbidden
        url = reverse("notification-mark-read", kwargs={"pk": self.notif2.id})
        res = self.client.post(url)
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # User 1 marks own notification read -> Should return 200 OK
        own_url = reverse("notification-mark-read", kwargs={"pk": self.notif1.id})
        own_res = self.client.post(own_url)
        self.assertEqual(own_res.status_code, status.HTTP_200_OK)
        self.notif1.refresh_from_db()
        self.assertTrue(self.notif1.is_read)

    def test_mark_all_read_api(self):
        url = reverse("notification-read-all")
        res = self.client.post(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.notif1.refresh_from_db()
        self.assertTrue(self.notif1.is_read)

    def test_notification_history_api(self):
        url = reverse("notification-history")
        res = self.client.get(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
