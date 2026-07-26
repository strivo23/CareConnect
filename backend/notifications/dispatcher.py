import logging
from django.utils import timezone
from django.contrib.auth import get_user_model
from django.db import transaction

from .models import Notification, NotificationLog
from .notification_service import send_push, send_email, SMSService, _safe_str

User = get_user_model()
logger = logging.getLogger(__name__)


class NotificationDispatcher:
    """
    Centralized Notification Dispatcher for CareConnect.
    Dispatches all notification channels (In-App, FCM, Email, SMS) from a single service.
    Enforces Priority Alert Routing:
      Resident -> Primary Guardian -> Security -> Available Volunteers
    Rules:
      - Only active users receive notifications. Inactive users skipped.
      - Deduplication per channel.
      - Audit logs for: Created, Delivered, Read, Deleted, Failed.
    """

    @classmethod
    def _log_event(cls, user, channel: str, status: str, recipient: str, title: str, message: str, error_message: str = None):
        try:
            NotificationLog.objects.create(
                user=user,
                channel=channel,
                status=status,
                recipient=recipient,
                title=title,
                message=message,
                error_message=error_message
            )
        except Exception as e:
            logger.error(f"Failed to record NotificationLog: {e}")

    @classmethod
    def _dispatch_to_user(cls, user, title: str, message: str, category: str = 'SOS', incident=None, recipient_role: str = 'RESIDENT', notification_type: str = 'SOS_CREATED', priority: str = 'HIGH', channels: list = None) -> list[Notification]:
        """
        Helper method to dispatch across requested channels for a single active user with deduplication & logging.
        """
        # Rule: Only active users receive notifications. Inactive users skipped.
        if not user or not getattr(user, 'is_active', True):
            cls._log_event(
                user=user,
                channel='SKIPPED',
                status='FAILURE',
                recipient=getattr(user, 'email', 'inactive_user'),
                title=title,
                message=message,
                error_message="User is inactive or null."
            )
            return []

        if channels is None:
            channels = ['IN_APP', 'FCM', 'EMAIL', 'SMS']

        dispatched_notifs = []
        now = timezone.now()

        # 1. In-App Notification
        if 'IN_APP' in channels:
            notif = Notification.objects.create(
                user=user,
                title=title,
                message=message,
                category=category,
                incident=incident,
                is_read=False,
                priority=priority,
                delivery_status='SENT',
                delivery_channel='IN_APP',
                recipient_role=recipient_role,
                notification_type=notification_type,
                location=incident.address if incident else None
            )
            cls._log_event(user, 'IN_APP', 'SUCCESS', user.email, title, message)
            dispatched_notifs.append(notif)
            # Log Notification Created event
            cls._log_event(user, 'IN_APP_CREATED', 'SUCCESS', user.email, title, f"Notification #{notif.id} Created")

        # FCM Payload
        fcm_data = {
            "incident_id": str(incident.id) if incident else "",
            "category": category,
            "priority": priority,
            "notification_type": notification_type,
            "click_action": "FLUTTER_NOTIFICATION_CLICK"
        }

        # 2. FCM Push
        if 'FCM' in channels:
            try:
                push_ok = send_push(user, title, message, data=fcm_data)
                cls._log_event(user, 'FCM', 'SUCCESS' if push_ok else 'FAILURE', user.email, title, message)
            except Exception as e:
                cls._log_event(user, 'FCM', 'FAILURE', user.email, title, message, error_message=str(e))

        # 3. Email (Gmail SMTP)
        if 'EMAIL' in channels and getattr(user, 'email', None):
            try:
                email_ok = send_email(user.email, title, message, user=user)
                cls._log_event(user, 'EMAIL', 'SUCCESS' if email_ok else 'FAILURE', user.email, title, message)
            except Exception as e:
                cls._log_event(user, 'EMAIL', 'FAILURE', user.email, title, message, error_message=str(e))

        # 4. SMS Service Abstraction
        if 'SMS' in channels and getattr(user, 'phone_number', None):
            try:
                sms_ok = SMSService.send_sms(user.phone_number, message, user=user)
                cls._log_event(user, 'SMS', 'SUCCESS' if sms_ok else 'FAILURE', user.phone_number, title, message)
            except Exception as e:
                cls._log_event(user, 'SMS', 'FAILURE', user.phone_number, title, message, error_message=str(e))

        return dispatched_notifs

    # ── 1. dispatch_sos_created ─────────────────────────────────────────────
    @classmethod
    def dispatch_sos_created(cls, incident) -> dict:
        """
        Dispatches multi-channel alerts when a new SOS incident is created.
        Priority Hierarchy:
          Resident -> Primary Guardian -> Security Staff -> Available Volunteers
        """
        resident = incident.resident
        cat_name = incident.category.name if incident.category else 'SOS Emergency'
        address = incident.address or 'Location unavailable'
        priority = incident.priority or 'CRITICAL'
        time_str = incident.created_at.strftime('%Y-%m-%d %H:%M:%S UTC') if incident.created_at else 'Just now'
        desc = incident.emergency_description or incident.message or 'Immediate assistance required.'

        summary = {'resident': 0, 'guardians': 0, 'security': 0, 'volunteers': 0}
        processed_users = set()

        # Step 1: Resident Confirmation
        if resident and resident.is_active and resident.id not in processed_users:
            processed_users.add(resident.id)
            cls._dispatch_to_user(
                user=resident,
                title="Emergency Alert Received",
                message=f"Your SOS incident ({cat_name}) has been received and dispatched.",
                category="sos",
                incident=incident,
                recipient_role="RESIDENT",
                notification_type="SOS_CREATED",
                priority=priority,
                channels=['IN_APP', 'FCM', 'EMAIL']
            )
            summary['resident'] += 1

        # Step 2: Primary Guardians
        from emergency.models import ResidentGuardian, Guardian, EmergencyContact
        links = ResidentGuardian.objects.filter(resident=resident, status='Active').select_related('guardian')
        for link in links:
            g_user = link.guardian
            if g_user and g_user.is_active and g_user.id not in processed_users:
                processed_users.add(g_user.id)
                body = (
                    f"Emergency SOS Alert!\n"
                    f"Resident Name: {resident.full_name}\n"
                    f"Category: {cat_name}\n"
                    f"Address: {address}\n"
                    f"Time: {time_str}\n"
                    f"Emergency Message: {desc}"
                )
                cls._dispatch_to_user(
                    user=g_user,
                    title="Emergency SOS Alert",
                    message=body,
                    category="sos",
                    incident=incident,
                    recipient_role="GUARDIAN",
                    notification_type="SOS_CREATED",
                    priority=priority,
                    channels=['IN_APP', 'FCM', 'EMAIL', 'SMS']
                )
                summary['guardians'] += 1

        # Step 3: Security Staff & Society Managers
        society = getattr(resident, 'society', None)
        security_query = User.objects.filter(role__in=['SECURITY', 'ADMIN', 'SOCIETY_MANAGER'], is_active=True)
        if society:
            security_query = security_query.filter(society=society)

        for sec in security_query:
            if sec.id not in processed_users:
                processed_users.add(sec.id)
                sec_msg = f"SECURITY ALERT: {resident.full_name} triggered SOS ({cat_name}) at {address}."
                cls._dispatch_to_user(
                    user=sec,
                    title="SECURITY ALERT: SOS Triggered",
                    message=sec_msg,
                    category="sos",
                    incident=incident,
                    recipient_role="SECURITY",
                    notification_type="SOS_CREATED",
                    priority="CRITICAL",
                    channels=['IN_APP', 'FCM', 'EMAIL', 'SMS']
                )
                summary['security'] += 1

        # Step 4: Available Volunteers
        volunteers = User.objects.filter(role='VOLUNTEER', is_active=True)
        for vol in volunteers:
            if vol.id not in processed_users:
                processed_users.add(vol.id)
                vol_msg = f"Volunteer Alert: SOS triggered near {address}. Category: {cat_name}."
                cls._dispatch_to_user(
                    user=vol,
                    title="Volunteer SOS Alert",
                    message=vol_msg,
                    category="sos",
                    incident=incident,
                    recipient_role="VOLUNTEER",
                    notification_type="SOS_CREATED",
                    priority="HIGH",
                    channels=['IN_APP', 'FCM']
                )
                summary['volunteers'] += 1

        return summary

    # ── 2. dispatch_guardian_response ───────────────────────────────────────
    @classmethod
    def dispatch_guardian_response(cls, incident, guardian, response_type: str = 'Accepted') -> dict:
        """
        Dispatches alerts when a guardian responds to an SOS (e.g. Accept / On The Way).
        """
        resident = incident.resident
        g_name = guardian.full_name if guardian else 'Guardian'
        title = f"Guardian Response: {response_type}"
        message = f"Guardian {g_name} has {response_type.lower()} the SOS alert for {resident.full_name}."

        processed_users = set()
        summary = {'resident': 0, 'security': 0}

        # Notify Resident
        if resident and resident.is_active:
            processed_users.add(resident.id)
            cls._dispatch_to_user(
                user=resident,
                title=title,
                message=message,
                category="guardian",
                incident=incident,
                recipient_role="RESIDENT",
                notification_type="GUARDIAN_RESPONSE",
                priority="HIGH",
                channels=['IN_APP', 'FCM', 'SMS']
            )
            summary['resident'] += 1

        # Notify Security
        security_query = User.objects.filter(role__in=['SECURITY', 'ADMIN'], is_active=True)
        for sec in security_query:
            if sec.id not in processed_users:
                processed_users.add(sec.id)
                cls._dispatch_to_user(
                    user=sec,
                    title=f"Security Notice: {title}",
                    message=message,
                    category="guardian",
                    incident=incident,
                    recipient_role="SECURITY",
                    notification_type="GUARDIAN_RESPONSE",
                    priority="MEDIUM",
                    channels=['IN_APP', 'FCM']
                )
                summary['security'] += 1

        return summary

    # ── 3. dispatch_incident_update ─────────────────────────────────────────
    @classmethod
    def dispatch_incident_update(cls, incident, update_notes: str = None) -> dict:
        """
        Dispatches alerts when an incident status updates (e.g. Pending -> In Progress).
        """
        resident = incident.resident
        cat_name = incident.category.name if incident.category else 'SOS'
        title = f"SOS Incident Update ({incident.status})"
        message = f"SOS #{incident.id} ({cat_name}) status changed to '{incident.status}'."
        if update_notes:
            message += f" Note: {update_notes}"

        processed_users = set()

        # Notify Resident
        if resident and resident.is_active:
            processed_users.add(resident.id)
            cls._dispatch_to_user(
                user=resident,
                title=title,
                message=message,
                category="sos",
                incident=incident,
                recipient_role="RESIDENT",
                notification_type="INCIDENT_UPDATE",
                priority="HIGH",
                channels=['IN_APP', 'FCM']
            )

        # Notify Linked Guardians
        from emergency.models import ResidentGuardian
        links = ResidentGuardian.objects.filter(resident=resident, status='Active').select_related('guardian')
        for link in links:
            g_user = link.guardian
            if g_user and g_user.is_active and g_user.id not in processed_users:
                processed_users.add(g_user.id)
                cls._dispatch_to_user(
                    user=g_user,
                    title=title,
                    message=message,
                    category="sos",
                    incident=incident,
                    recipient_role="GUARDIAN",
                    notification_type="INCIDENT_UPDATE",
                    priority="HIGH",
                    channels=['IN_APP', 'FCM']
                )

        return {'status': incident.status, 'notified_users': len(processed_users)}

    # ── 4. dispatch_incident_closed ─────────────────────────────────────────
    @classmethod
    def dispatch_incident_closed(cls, incident, resolution_notes: str = None) -> dict:
        """
        Dispatches alerts when an incident is resolved or cancelled.
        """
        resident = incident.resident
        title = f"SOS Incident {incident.status}"
        message = f"SOS #{incident.id} has been marked as '{incident.status}'."
        if resolution_notes:
            message += f" Resolution: {resolution_notes}"

        processed_users = set()

        # Notify Resident
        if resident and resident.is_active:
            processed_users.add(resident.id)
            cls._dispatch_to_user(
                user=resident,
                title=title,
                message=message,
                category="sos",
                incident=incident,
                recipient_role="RESIDENT",
                notification_type="INCIDENT_CLOSED",
                priority="MEDIUM",
                channels=['IN_APP', 'FCM']
            )

        # Notify Guardians
        from emergency.models import ResidentGuardian
        links = ResidentGuardian.objects.filter(resident=resident, status='Active').select_related('guardian')
        for link in links:
            g_user = link.guardian
            if g_user and g_user.is_active and g_user.id not in processed_users:
                processed_users.add(g_user.id)
                cls._dispatch_to_user(
                    user=g_user,
                    title=title,
                    message=message,
                    category="sos",
                    incident=incident,
                    recipient_role="GUARDIAN",
                    notification_type="INCIDENT_CLOSED",
                    priority="MEDIUM",
                    channels=['IN_APP', 'FCM']
                )

        # Notify Security
        security_query = User.objects.filter(role__in=['SECURITY', 'ADMIN'], is_active=True)
        for sec in security_query:
            if sec.id not in processed_users:
                processed_users.add(sec.id)
                cls._dispatch_to_user(
                    user=sec,
                    title=title,
                    message=message,
                    category="sos",
                    incident=incident,
                    recipient_role="SECURITY",
                    notification_type="INCIDENT_CLOSED",
                    priority="MEDIUM",
                    channels=['IN_APP', 'FCM']
                )

        return {'status': incident.status, 'notified_users': len(processed_users)}
