"""
sos/services.py

Business-logic service layer for the SOS module.
Keeps views thin and logic reusable/testable.
"""

import threading
import time
import math
from decimal import Decimal
from django.utils import timezone
from django.db import transaction
from django.db.models import Q
from django.contrib.auth import get_user_model

from notifications.models import Notification
from notifications.services import NotificationEngineService
from notifications.notification_service import (
    notify_guardians,
    notify_security,
    notify_volunteers,
    send_email,
    send_push,
    SMSService,
)
from notifications.dispatcher import NotificationDispatcher
from .models import SOSIncident, EmergencyCategory, EscalationConfig, EscalationLog, AssignmentLog, IncidentStatusLog, IncidentChatMessage, IncidentResponseUpdate
from emergency.models import Guardian, EmergencyContact


def haversine(lat1, lon1, lat2, lon2):
    # distance in meters
    R = 6371000  # radius of Earth in meters
    phi1 = math.radians(float(lat1))
    phi2 = math.radians(float(lat2))
    dphi = math.radians(float(lat2 - lat1))
    dlambda = math.radians(float(lon2 - lon1))
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c


class AlreadyAssignedException(Exception):
    """Raised when an SOS incident is already assigned to a responder."""
    pass


# Valid status transitions: current_status -> allowed_next_statuses
STATUS_TRANSITIONS = {
    "Pending":     ["Accepted", "Assigned", "Cancelled"],
    "Accepted":    ["In Progress", "Assigned", "Cancelled"],
    "Assigned":    ["In Progress", "Cancelled"],
    "In Progress": ["Resolved", "Cancelled"],
    "Resolved":    [],           # terminal state
    "Cancelled":   [],           # terminal state
}



class SOSService:
    """
    Centralised service for SOS business logic.
    Call from views; never call ORM directly in views for these operations.
    """

    @staticmethod
    def reverse_geocode_details(latitude, longitude) -> dict:
        """
        Reverse geocodes (lat, lon) using Nominatim API and returns structured components:
        {
          "address": "...",
          "city": "...",
          "state": "...",
          "country": "...",
          "pincode": "..."
        }
        Does not block on failure.
        """
        default_res = {
            "address": "Location could not be resolved",
            "city": "",
            "state": "",
            "country": "",
            "pincode": ""
        }
        if latitude is None or longitude is None:
            return default_res

        import sys
        if 'test' in sys.argv:
            return {
                "address": f"Mock Street, {latitude}, {longitude}, Test City, Test State, 123456, India",
                "city": "Test City",
                "state": "Test State",
                "country": "India",
                "pincode": "123456"
            }

        import requests

        url = "https://nominatim.openstreetmap.org/reverse"
        params = {
            "lat": str(latitude),
            "lon": str(longitude),
            "format": "jsonv2"
        }
        headers = {
            "User-Agent": "CareConnect/1.0 (Student Project)"
        }

        for attempt in range(2):
            try:
                response = requests.get(url, params=params, headers=headers, timeout=5)
                if response.status_code == 200:
                    data = response.json()
                    addr = data.get("address", {})
                    city = addr.get("city") or addr.get("town") or addr.get("village") or addr.get("city_district") or ""
                    state = addr.get("state") or addr.get("state_district") or ""
                    country = addr.get("country") or ""
                    pincode = addr.get("postcode") or ""

                    parts = []
                    street = addr.get("road") or addr.get("house_number") or addr.get("pedestrian") or addr.get("suburb")
                    if street:
                        parts.append(street)
                    area = addr.get("neighbourhood") or addr.get("residential") or addr.get("subdistrict") or addr.get("county")
                    if area and area not in parts:
                        parts.append(area)
                    if city and city not in parts:
                        parts.append(city)
                    if state and state not in parts:
                        parts.append(state)
                    if pincode and pincode not in parts:
                        parts.append(pincode)
                    if country and country not in parts:
                        parts.append(country)

                    formatted_addr = ", ".join(parts) if parts else data.get("display_name", "Location could not be resolved")
                    return {
                        "address": formatted_addr,
                        "city": city,
                        "state": state,
                        "country": country,
                        "pincode": pincode
                    }
            except Exception as e:
                print(f"[REVERSE GEOCODE] Attempt {attempt+1} failed: {e}", flush=True)

        return default_res

    @staticmethod
    def reverse_geocode(latitude, longitude) -> str:
        """
        Reverse geocodes (lat, lon) to a readable address string.
        """
        res = SOSService.reverse_geocode_details(latitude, longitude)
        return res["address"]

    @staticmethod
    def create_incident(user, validated_data: dict) -> SOSIncident:
        """
        Create a new SOS incident for *user*.

        - Enforces active resident check
        - Checks for recent duplicate active SOS requests
        - Forces status = 'Pending'
        - Creates an 'Emergency Alert Received' notification for the resident
        - Notifies primary guardian, security, and volunteers
        """
        if not user.is_active:
            raise ValueError("Resident account is disabled or unapproved.")

        # Duplicate request check
        recent_duplicate = SOSIncident.objects.filter(
            resident=user,
            status__in=["Pending", "Accepted", "In Progress"],
            created_at__gte=timezone.now() - timezone.timedelta(seconds=30)
        ).first()
        if recent_duplicate:
            raise ValueError(f"An active SOS incident (#{recent_duplicate.id}) is already in progress. Please wait before sending another.")

        validated_data["resident"] = user
        validated_data["status"] = "Pending"

        # Reverse geocode if coordinates are present
        lat = validated_data.get("latitude")
        lng = validated_data.get("longitude")
        addr_val = validated_data.get("address")
        if lat is not None and lng is not None:
            geo_details = SOSService.reverse_geocode_details(lat, lng)
            if not addr_val or addr_val in ["Address not resolved", "Address unavailable", "Location unavailable", ""]:
                validated_data["address"] = geo_details["address"]
            if not validated_data.get("city"):
                validated_data["city"] = geo_details["city"]
            if not validated_data.get("state"):
                validated_data["state"] = geo_details["state"]
            if not validated_data.get("country"):
                validated_data["country"] = geo_details["country"]
            if not validated_data.get("pincode"):
                validated_data["pincode"] = geo_details["pincode"]

        with transaction.atomic():
            incident = SOSIncident.objects.create(**validated_data)
            
            # Log SOS Created
            print("SOS Created", flush=True)

            # Auto-create notification for the resident
            Notification.objects.create(
                user=user,
                title="Emergency Alert Received",
                message=(
                    f"Your SOS incident ({incident.category.name if incident.category else 'SOS Emergency'}) has been received "
                    f"and is being processed. Status: Pending."
                ),
                category="sos",
            )

            # Get response window configuration
            config, _ = EscalationConfig.objects.get_or_create(
                id=1,
                defaults={
                    'response_time_minutes': 5,
                    'response_time_window': 30,
                    'escalation_enabled': True,
                    'notify_security': True,
                    'notify_volunteers': True,
                    'notify_admin': True,
                }
            )
            
            if config.escalation_enabled:
                window = config.response_time_window if config.response_time_window else (config.response_time_minutes * 60)
                now = timezone.now()

                # Create Escalation Logs
                # Step 1: Primary Guardian (trigger immediately)
                EscalationLog.objects.create(
                    incident=incident,
                    step='Primary Guardian',
                    escalation_level='Primary Guardian',
                    new_recipient='Primary Guardian',
                    status='TRIGGERED',
                    scheduled_at=now,
                    triggered_at=now
                )
                # Step 2: Secondary Guardian (pending, wait 1 window)
                EscalationLog.objects.create(
                    incident=incident,
                    step='Secondary Guardian',
                    escalation_level='Secondary Guardian',
                    previous_recipient='Primary Guardian',
                    new_recipient='Secondary Guardian',
                    status='PENDING',
                    scheduled_at=now + timezone.timedelta(seconds=window)
                )
                # Step 3: Emergency Contacts (pending, wait 2 windows)
                EscalationLog.objects.create(
                    incident=incident,
                    step='Emergency Contacts',
                    escalation_level='Emergency Contacts',
                    previous_recipient='Secondary Guardian',
                    new_recipient='Emergency Contacts',
                    status='PENDING',
                    scheduled_at=now + timezone.timedelta(seconds=window * 2)
                )
                
                step_offset = 3
                if config.notify_security:
                    EscalationLog.objects.create(
                        incident=incident,
                        step='Security',
                        escalation_level='Security',
                        previous_recipient='Emergency Contacts',
                        new_recipient='Security Staff',
                        status='PENDING',
                        scheduled_at=now + timezone.timedelta(seconds=window * step_offset)
                    )
                    step_offset += 1

                if config.notify_volunteers:
                    EscalationLog.objects.create(
                        incident=incident,
                        step='Volunteers',
                        escalation_level='Volunteers',
                        previous_recipient='Security',
                        new_recipient='Community Volunteers',
                        status='PENDING',
                        scheduled_at=now + timezone.timedelta(seconds=window * step_offset)
                    )
                    step_offset += 1

                if config.notify_admin:
                    EscalationLog.objects.create(
                        incident=incident,
                        step='Admin',
                        escalation_level='Admin',
                        previous_recipient='Volunteers',
                        new_recipient='System Admin',
                        status='PENDING',
                        scheduled_at=now + timezone.timedelta(seconds=window * step_offset)
                    )

            # Dispatch notifications safely
            try:
                NotificationDispatcher.dispatch_sos_created(incident)
                SOSService._notify_primary_guardians(incident)
                notify_guardians(incident)
            except Exception as notif_err:
                print(f"[SOSService] Notification dispatch warning: {notif_err}", flush=True)

            # Create SYSTEM chat message for incident creation
            try:
                IncidentChatService.create_system_message(
                    incident,
                    f"Emergency SOS triggered by {user.full_name or user.email}."
                )
            except Exception as chat_err:
                print(f"[SOSService] System chat message warning: {chat_err}", flush=True)

            # Notify nearby volunteers if coordinates are available
            volunteer_count = 0
            if incident.latitude is not None and incident.longitude is not None and config.notify_volunteers:
                try:
                    from accounts.models import VolunteerProfile
                    volunteers = VolunteerProfile.objects.filter(is_online=True, latitude__isnull=False, longitude__isnull=False).select_related('user')
                    for vol in volunteers:
                        dist = haversine(incident.latitude, incident.longitude, vol.latitude, vol.longitude)
                        if dist <= vol.visibility_radius:
                            volunteer_count += 1
                            NotificationEngineService.dispatch_notification(
                                user=vol.user,
                                title="🚨 Nearby SOS Community Broadcast",
                                message=f"Urgent: {incident.resident.full_name} needs help nearby. Distance: {dist:.0f}m.",
                                category="sos",
                                incident=incident
                            )
                            if vol.user.email:
                                NotificationEngineService.send_sos_email(
                                    email=vol.user.email,
                                    incident=incident,
                                    user=vol.user
                                )
                except Exception as vol_err:
                    print(f"[SOSService] Volunteer notification warning: {vol_err}", flush=True)

            from emergency.models import ResidentGuardian, EmergencyContact
            guardian_count = ResidentGuardian.objects.filter(resident=user, status='Active').count()
            contacts_count = EmergencyContact.objects.filter(resident=user).count()
            User_Model = get_user_model()
            security_count = User_Model.objects.filter(role='SECURITY', is_active=True).count()

            incident.notifications_summary = {
                "guardian_notified": guardian_count > 0,
                "guardian_count": guardian_count,
                "security_notified": security_count > 0,
                "security_count": security_count,
                "volunteer_notified": volunteer_count > 0,
                "volunteer_count": volunteer_count,
                "emergency_contacts_notified": contacts_count > 0,
                "contacts_count": contacts_count,
            }

        return incident

    @staticmethod
    def _notify_primary_guardians(incident: SOSIncident) -> bool:
        """Notify primary guardians immediately."""
        resident = incident.resident
        User = get_user_model()
        from emergency.models import ResidentGuardian

        primary_user_ids = set(User.objects.filter(
            linked_residents__resident=resident,
            linked_residents__is_primary=True,
            linked_residents__status='Active'
        ).exclude(id=resident.id).values_list('id', flat=True))

        contact_phones = list(EmergencyContact.objects.filter(resident=resident, is_primary=True).values_list('phone', flat=True))
        guardian_phones = list(Guardian.objects.filter(resident=resident, is_primary=True).values_list('phone', flat=True))
        all_primary_phones = set(contact_phones + guardian_phones)

        if all_primary_phones:
            matched_ids = User.objects.filter(phone_number__in=all_primary_phones).exclude(id=resident.id).values_list('id', flat=True)
            primary_user_ids.update(matched_ids)

        primary_guardians = User.objects.filter(id__in=primary_user_ids)

        notification_title = "🚨 Emergency SOS"
        notification_message = (
            f"{resident.full_name} needs immediate assistance! "
            f"Category: {incident.category.name if incident.category else 'SOS'}. "
            f"Priority: {incident.priority}."
        )
        if incident.address:
            notification_message += f" Address: {incident.address}"

        for u in primary_guardians:
            print(f"Notifying primary guardian: {u.full_name} ({u.role})")
            NotificationEngineService.dispatch_notification(
                user=u,
                title=notification_title,
                message=notification_message,
                category="sos",
                incident=incident,
                priority=incident.priority,
                channels=['IN_APP', 'FCM', 'SMS']
            )
            if u.email:
                NotificationEngineService.send_sos_email(
                    email=u.email,
                    incident=incident,
                    user=u
                )

        return True

    @staticmethod
    def _notify_secondary_guardians(incident: SOSIncident) -> bool:
        """Notify secondary guardians (step 2)."""
        resident = incident.resident
        User = get_user_model()
        from emergency.models import ResidentGuardian

        secondary_guardians = User.objects.filter(
            linked_residents__resident=resident,
            linked_residents__is_primary=False,
            linked_residents__status='Active'
        ).exclude(id=resident.id)

        notification_title = "🚨 Emergency SOS Escalation (Secondary Guardian)"
        notification_message = (
            f"{resident.full_name} needs assistance! Primary Guardian has not responded. "
            f"Category: {incident.category.name if incident.category else 'SOS'}. "
            f"Priority: {incident.priority}."
        )
        if incident.address:
            notification_message += f" Address: {incident.address}"

        for u in secondary_guardians:
            print(f"Notifying secondary guardian: {u.full_name} ({u.role})")
            NotificationEngineService.dispatch_notification(
                user=u,
                title=notification_title,
                message=notification_message,
                category="sos",
                incident=incident,
                priority=incident.priority,
                channels=['IN_APP', 'FCM', 'SMS']
            )
            if u.email:
                NotificationEngineService.send_sos_email(
                    email=u.email,
                    incident=incident,
                    user=u
                )

        return True

    @staticmethod
    def _notify_emergency_contacts(incident: SOSIncident) -> bool:
        """Notify verified emergency contacts (step3)."""
        resident = incident.resident
        User = get_user_model()

        contacts = EmergencyContact.objects.filter(resident=resident, verified=True)
        contact_phones = list(contacts.values_list('phone', flat=True))
        contact_users = User.objects.filter(phone_number__in=contact_phones).exclude(id=resident.id)

        notification_title = "🚨 Emergency SOS Escalation (Emergency Contact)"
        notification_message = (
            f"SOS alert escalated for {resident.full_name}. No response from guardians yet. "
            f"Category: {incident.category.name if incident.category else 'SOS'}. "
            f"Priority: {incident.priority}."
        )
        if incident.address:
            notification_message += f" Address: {incident.address}"

        for u in contact_users:
            print(f"Notifying emergency contact: {u.full_name} ({u.role})")
            NotificationEngineService.dispatch_notification(
                user=u,
                title=notification_title,
                message=notification_message,
                category="sos",
                incident=incident,
                priority=incident.priority,
                channels=['IN_APP', 'FCM', 'SMS']
            )
            if u.email:
                NotificationEngineService.send_sos_email(
                    email=u.email,
                    incident=incident,
                    user=u
                )

        # Fallback to direct SMS for verified contacts who aren't registered users
        registered_phones = set(contact_users.values_list('phone_number', flat=True))
        for contact in contacts:
            if contact.phone not in registered_phones:
                NotificationEngineService.send_sms(
                    phone=contact.phone,
                    message=notification_message
                )

        return True

    @staticmethod
    def _notify_security_and_admins(incident: SOSIncident) -> bool:
        """Notify security and admins (step4)."""
        resident = incident.resident

        # Find resident's society
        resident_profile = getattr(resident, 'resident_profile', None)
        society = resident_profile.society if resident_profile else None

        User = get_user_model()

        # Security staff
        security_staff = User.objects.filter(role='SECURITY')
        if society:
            security_staff = security_staff.filter(security_profile__assigned_society=society)

        # Admins
        admins = User.objects.filter(role='ADMIN')

        recipients = list(security_staff) + list(admins)

        notification_title = "🚨 CRITICAL: SOS Alert Escalated to Security/Admin"
        notification_message = (
            f"Critical emergency alert for {resident.full_name} has escalated without responses. "
            f"Category: {incident.category.name if incident.category else 'SOS'}. "
            f"Priority: {incident.priority}."
        )
        if incident.address:
            notification_message += f" Address: {incident.address}"

        for r in set(recipients):
            print(f"Notifying security/admin: {r.full_name} ({r.role})")
            NotificationEngineService.dispatch_notification(
                user=r,
                title=notification_title,
                message=notification_message,
                category="sos",
                incident=incident,
                priority=incident.priority,
                channels=['IN_APP', 'FCM', 'SMS']
            )
            if r.email:
                NotificationEngineService.send_sos_email(
                    email=r.email,
                    incident=incident,
                    user=r
                )

        return True

    @staticmethod
    def _build_location_string(incident: SOSIncident) -> str:
        loc_str = ""
        if incident.latitude is not None and incident.longitude is not None:
            loc_str = f"{incident.latitude}, {incident.longitude}"
            if incident.address:
                loc_str = f"{loc_str} ({incident.address})"
        return loc_str

    @staticmethod
    def update_status(incident: SOSIncident, new_status: str, actor=None) -> SOSIncident:
        """
        Transition *incident* to *new_status*.
        Raises ValueError for invalid transitions.
        Sends a notification to the resident on every status change.
        """
        allowed = STATUS_TRANSITIONS.get(incident.status, [])
        if new_status not in allowed:
            raise ValueError(
                f"Cannot transition from '{incident.status}' to '{new_status}'. "
                f"Allowed: {allowed}"
            )

        with transaction.atomic():
            incident.status = new_status
            incident.save(update_fields=["status", "updated_at"])

            # If accepted or resolved, cancel any pending escalations
            if new_status in ["Accepted", "Resolved", "Cancelled"]:
                EscalationLog.objects.filter(incident=incident, status='PENDING').update(status='CANCELLED')

            # Notify the resident about the status change
            Notification.objects.create(
                user=incident.resident,
                title=f"SOS Update - {new_status}",
                message=(
                    f"Your SOS incident ({incident.category.name}) status has been "
                    f"updated to '{new_status}'."
                ),
                category="sos",
            )

        return incident

    @staticmethod
    def accept_incident(incident: SOSIncident, actor=None) -> SOSIncident:
        """
        Accept an SOS incident, stopping all auto-escalation.
        """
        with transaction.atomic():
            updated = SOSService.update_status(incident, "Accepted", actor=actor)
            
            actor_name = getattr(actor, 'full_name', str(actor)) if actor else 'Assignee'
            EscalationLog.objects.create(
                incident=incident,
                step='Accepted',
                escalation_level='Accepted',
                previous_recipient=actor_name,
                new_recipient=actor_name,
                reason='SOS accepted by guardian/responder',
                status='ACCEPTED',
                response_status='Accepted',
                scheduled_at=timezone.now(),
                triggered_at=timezone.now()
            )
            
            # Cancel all remaining pending escalations
            EscalationLog.objects.filter(incident=incident, status='PENDING').update(
                status='CANCELLED',
                response_status='Cancelled due to acceptance'
            )
            
        return updated

    @staticmethod
    def accept_and_assign_incident(incident_id: int, responder, ip_address: str = None) -> SOSIncident:
        """
        Formally accept an SOS incident by a Volunteer or Security responder.
        Uses select_for_update() to prevent race conditions & duplicate assignments.
        """
        with transaction.atomic():
            try:
                incident = SOSIncident.objects.select_for_update().select_related("resident", "category").get(pk=incident_id)
            except SOSIncident.DoesNotExist:
                raise SOSIncident.DoesNotExist("SOS incident not found.")

            if incident.assigned_responder is not None or incident.assignment_status in ["Assigned", "In Progress", "Resolved"] or incident.status in ["Assigned", "In Progress", "Resolved"]:
                raise AlreadyAssignedException("Incident already assigned.")

            from emergency.models import ResidentGuardian
            is_guardian = ResidentGuardian.objects.filter(guardian=responder, resident=incident.resident, status='Active').exists()
            role_display = "Guardian" if is_guardian else ("Volunteer" if responder.role == "VOLUNTEER" else ("Security" if responder.role == "SECURITY" else responder.role.title()))
            prev_status = incident.status
            now = timezone.now()

            incident.assigned_responder = responder
            incident.assigned_role = role_display
            incident.accepted_at = now
            incident.assignment_status = "Assigned"
            incident.status = "Accepted"
            incident.save()

            # Audit log entry
            AssignmentLog.objects.create(
                incident=incident,
                responder=responder,
                role=role_display,
                accepted_at=now,
                previous_status=prev_status,
                new_status="Assigned",
                ip_address=ip_address,
            )

            # Cancel remaining auto-escalation logs
            EscalationLog.objects.filter(incident=incident, status='PENDING').update(
                status='CANCELLED',
                response_status=f'Cancelled due to assignment to {responder.full_name}'
            )

            # 1. Notify Resident
            NotificationEngineService.dispatch_notification(
                user=incident.resident,
                title="🚨 SOS Incident Accepted",
                message=f"{role_display} {responder.full_name or responder.email} has accepted your SOS.",
                category="sos",
                incident=incident,
                priority="HIGH",
                channels=['IN_APP', 'FCM', 'SMS']
            )

            # 2. Notify Primary Guardian(s)
            SOSService._notify_guardians_of_assignment(incident, responder, role_display)

            # 3. Notify Admins
            User = get_user_model()
            admins = User.objects.filter(role="ADMIN")
            for admin_user in admins:
                NotificationEngineService.dispatch_notification(
                    user=admin_user,
                    title="🚨 SOS Incident Assigned",
                    message=f"{role_display} {responder.full_name} has accepted incident #{incident.id} for {incident.resident.full_name}.",
                    category="sos",
                    incident=incident,
                    priority="HIGH",
                    channels=['IN_APP', 'FCM']
                )

        return incident

    @staticmethod
    def _notify_guardians_of_assignment(incident: SOSIncident, responder, role_display: str):
        resident = incident.resident
        User = get_user_model()

        contact_phones = list(EmergencyContact.objects.filter(resident=resident, is_primary=True).values_list('phone', flat=True))
        guardian_phones = list(Guardian.objects.filter(resident=resident, is_primary=True).values_list('phone', flat=True))
        all_primary_phones = set(contact_phones + guardian_phones)

        primary_user_ids = set(User.objects.filter(
            linked_residents__resident=resident,
            linked_residents__is_primary=True,
            linked_residents__status='Active'
        ).exclude(id=resident.id).values_list('id', flat=True))

        if all_primary_phones:
            matched_ids = User.objects.filter(phone_number__in=all_primary_phones).exclude(id=resident.id).values_list('id', flat=True)
            primary_user_ids.update(matched_ids)

        primary_guardians = User.objects.filter(id__in=primary_user_ids)
        msg = f"{role_display} {responder.full_name} has accepted emergency request for {resident.full_name}."

        for g in primary_guardians:
            NotificationEngineService.dispatch_notification(
                user=g,
                title="🚨 SOS Incident Accepted",
                message=msg,
                category="sos",
                incident=incident,
                priority="HIGH",
                channels=['IN_APP', 'FCM', 'SMS']
            )

    @staticmethod
    def reject_incident(incident: SOSIncident, actor=None, reason: str = "") -> SOSIncident:
        """
        Reject an SOS incident, recording rejection and immediately triggering the next escalation step.
        """
        now = timezone.now()
        with transaction.atomic():
            actor_name = getattr(actor, 'full_name', str(actor)) if actor else 'Guardian'
            
            EscalationLog.objects.create(
                incident=incident,
                step='Rejected',
                escalation_level='Rejected',
                previous_recipient=actor_name,
                new_recipient='Escalated',
                reason=reason or 'SOS rejected by primary/secondary guardian',
                status='REJECTED',
                response_status='Rejected',
                scheduled_at=now,
                triggered_at=now
            )

            # Trigger immediate escalation by advancing next pending log to scheduled_at = now
            next_step = EscalationLog.objects.filter(incident=incident, status='PENDING').order_by('scheduled_at').first()
            if next_step:
                next_step.scheduled_at = now
                next_step.save(update_fields=['scheduled_at'])

        # Trigger pending escalations process via Celery task or direct fallback
        try:
            from .tasks import trigger_incident_escalation
            trigger_incident_escalation.delay(incident.id)
        except Exception:
            SOSService.process_pending_escalations()

        return incident

    @staticmethod
    def process_pending_escalations():
        """
        Invoked by background daemon or manually.
        Checks for expired pending escalation logs and processes them.
        """
        now = timezone.now()
        pending_steps = EscalationLog.objects.filter(status='PENDING', scheduled_at__lte=now).select_related('incident', 'incident__resident')

        for step in pending_steps:
            incident = step.incident
            resident = incident.resident

            # If incident is no longer pending, cancel this and all subsequent steps
            if incident.status != 'Pending':
                EscalationLog.objects.filter(incident=incident, status='PENDING').update(status='CANCELLED')
                continue

            # Process step
            print(f"[ESCALATION] Triggering step '{step.step}' for incident #{incident.id} ({resident.full_name})")
            success = False
            if step.step == 'Secondary Guardian':
                success = SOSService._notify_secondary_guardians(incident)
            elif step.step == 'Emergency Contacts':
                success = SOSService._notify_emergency_contacts(incident)
            elif step.step == 'Security/Admin':
                success = SOSService._notify_security_and_admins(incident)

            step.status = 'TRIGGERED'
            step.triggered_at = now
            step.save(update_fields=['status', 'triggered_at'])

    @staticmethod
    def _notify_secondary_guardians(incident: SOSIncident) -> bool:
        resident = incident.resident
        secondary = Guardian.objects.filter(resident=resident, is_primary=False, verified=True)
        phones = list(secondary.values_list('phone', flat=True))
        
        User = get_user_model()
        users = User.objects.filter(phone_number__in=phones).exclude(id=resident.id)
        
        for u in users:
            NotificationEngineService.dispatch_notification(
                user=u,
                title="Emergency SOS Escalation (Secondary Guardian)",
                message=f"{resident.full_name} needs assistance. Primary Guardian has not responded.",
                category="sos",
                incident=incident
            )
        return True

    @staticmethod
    def _notify_emergency_contacts(incident: SOSIncident) -> bool:
        resident = incident.resident
        contacts = EmergencyContact.objects.filter(resident=resident, verified=True)
        phones = list(contacts.values_list('phone', flat=True))
        emails = list(contacts.values_list('email', flat=True))
        
        User = get_user_model()
        # Find registered users or dispatch via phone/email direct fallback
        users = User.objects.filter(Q(phone_number__in=phones) | Q(email__in=emails)).exclude(id=resident.id)
        
        for u in users:
            NotificationEngineService.dispatch_notification(
                user=u,
                title="Emergency SOS Escalation (Emergency Contact)",
                message=f"SOS alert escalated for {resident.full_name}. Please verify.",
                category="sos",
                incident=incident
            )
        
        # Fallback to direct SMS for verified contacts who aren't registered users
        registered_phones = set(users.values_list('phone_number', flat=True))
        for contact in contacts:
            if contact.phone not in registered_phones:
                NotificationEngineService.send_sms(
                    phone=contact.phone,
                    message=f"Alert: Emergency SOS triggered by {resident.full_name} has escalated. Please check on them."
                )
        return True

    @staticmethod
    def _notify_security_and_admins(incident: SOSIncident) -> bool:
        resident = incident.resident
        
        # Find resident's society
        resident_profile = getattr(resident, 'resident_profile', None)
        society = resident_profile.society if resident_profile else None
        
        User = get_user_model()
        
        # Security staff
        security_staff = User.objects.filter(role='SECURITY')
        if society:
            security_staff = security_staff.filter(security_profile__assigned_society=society)
            
        # Admins
        admins = User.objects.filter(role='ADMIN')
        
        recipients = list(security_staff) + list(admins)
        
        for r in set(recipients):
            NotificationEngineService.dispatch_notification(
                user=r,
                title="CRITICAL: SOS Alert Escalated to Security/Admin",
                message=f"Critical emergency alert for {resident.full_name} has escalated without responses.",
                category="sos",
                incident=incident
            )
        return True

    @classmethod
    def start_escalation_daemon(cls):
        """Deprecated: Auto-escalation is handled by Celery workers and Celery Beat scheduler."""
        print("[CELERY ARCHITECTURE] Auto-escalation active via Celery worker and Celery Beat schedule.")


class IncidentLifecycleService:
    LIFECYCLE_TRANSITIONS = {
        "OPEN": ["ACTIVE"],
        "ACTIVE": ["ESCALATED", "RESOLVED"],
        "ESCALATED": ["RESOLVED"],
        "RESOLVED": ["CLOSED"],
        "CLOSED": [],
    }

    # Map legacy & current status strings to standardized lifecycle states
    STATUS_MAP = {
        "Pending": "OPEN",
        "Accepted": "ACTIVE",
        "Assigned": "ACTIVE",
        "In Progress": "ACTIVE",
        "Escalated": "ESCALATED",
        "Resolved": "RESOLVED",
        "Closed": "CLOSED",
        "Cancelled": "CLOSED",
        "OPEN": "OPEN",
        "ACTIVE": "ACTIVE",
        "ESCALATED": "ESCALATED",
        "RESOLVED": "RESOLVED",
        "CLOSED": "CLOSED",
    }

    ROLE_TRANSITIONS = {
        "RESIDENT": [],
        "VOLUNTEER": [("OPEN", "ACTIVE"), ("ACTIVE", "RESOLVED")],
        "SECURITY": [("OPEN", "ACTIVE"), ("ACTIVE", "ESCALATED"), ("ESCALATED", "RESOLVED")],
        "ADMIN": [
            ("OPEN", "ACTIVE"),
            ("ACTIVE", "ESCALATED"),
            ("ACTIVE", "RESOLVED"),
            ("ESCALATED", "RESOLVED"),
            ("RESOLVED", "CLOSED"),
        ],
        "STAFF": [
            ("OPEN", "ACTIVE"),
            ("ACTIVE", "ESCALATED"),
            ("ACTIVE", "RESOLVED"),
            ("ESCALATED", "RESOLVED"),
            ("RESOLVED", "CLOSED"),
        ],
    }

    @classmethod
    def get_allowed_next_states(cls, current_status: str, role: str) -> list:
        current_state = cls.STATUS_MAP.get(current_status, "OPEN")
        possible_next = cls.LIFECYCLE_TRANSITIONS.get(current_state, [])
        role_allowed = cls.ROLE_TRANSITIONS.get(role, [])
        allowed = []
        for next_st in possible_next:
            if (current_state, next_st) in role_allowed:
                allowed.append(next_st)
        return allowed

    @classmethod
    def transition_status(
        cls,
        incident_id: int,
        new_status: str,
        user,
        remarks: str = None,
        ip_address: str = None
    ) -> SOSIncident:
        with transaction.atomic():
            try:
                incident = SOSIncident.objects.select_for_update().select_related("resident", "category").get(pk=incident_id)
            except SOSIncident.DoesNotExist:
                raise ValueError("Incident not found.")

            old_state = cls.STATUS_MAP.get(incident.current_status, cls.STATUS_MAP.get(incident.status, "OPEN"))
            target_state = cls.STATUS_MAP.get(new_status, new_status.upper())

            if old_state == "CLOSED":
                raise ValueError("Incident is CLOSED and cannot transition anywhere.")

            if target_state not in cls.LIFECYCLE_TRANSITIONS.get(old_state, []):
                raise ValueError(f"Invalid transition from '{old_state}' to '{target_state}'. Allowed next states: {cls.LIFECYCLE_TRANSITIONS.get(old_state, [])}")

            role = getattr(user, 'role', 'RESIDENT')
            allowed_for_role = cls.ROLE_TRANSITIONS.get(role, [])
            if (old_state, target_state) not in allowed_for_role:
                raise PermissionError(f"Role '{role}' is not authorized to transition incident from '{old_state}' to '{target_state}'.")

            now = timezone.now()
            incident.current_status = target_state

            # Sync legacy status field
            legacy_map = {
                "OPEN": "Pending",
                "ACTIVE": "In Progress",
                "ESCALATED": "Escalated",
                "RESOLVED": "Resolved",
                "CLOSED": "Closed",
            }
            incident.status = legacy_map.get(target_state, target_state)

            if target_state == "ACTIVE":
                incident.active_at = now
            elif target_state == "ESCALATED":
                incident.escalated_at = now
            elif target_state == "RESOLVED":
                incident.resolved_at = now
                incident.resolved_by = user
            elif target_state == "CLOSED":
                incident.closed_at = now
                incident.closed_by = user

                   # Record audit log
            IncidentStatusLog.objects.create(
                incident=incident,
                old_status=old_state,
                new_status=target_state,
                changed_by=user,
                role=role,
                remarks=remarks or f"Status transitioned to {target_state}",
                ip_address=ip_address
            )

            # Notification triggering
            cls._notify_lifecycle_change(incident, old_state, target_state, user)

            return incident


class IncidentLifecycleService:
    LIFECYCLE_TRANSITIONS = {
        "OPEN": ["ACTIVE"],
        "ACTIVE": ["ESCALATED", "RESOLVED"],
        "ESCALATED": ["RESOLVED"],
        "RESOLVED": ["CLOSED"],
        "CLOSED": [],
    }

    # Map legacy & current status strings to standardized lifecycle states
    STATUS_MAP = {
        "Pending": "OPEN",
        "Accepted": "ACTIVE",
        "Assigned": "ACTIVE",
        "In Progress": "ACTIVE",
        "Escalated": "ESCALATED",
        "Resolved": "RESOLVED",
        "Closed": "CLOSED",
        "Cancelled": "CLOSED",
        "OPEN": "OPEN",
        "ACTIVE": "ACTIVE",
        "ESCALATED": "ESCALATED",
        "RESOLVED": "RESOLVED",
        "CLOSED": "CLOSED",
    }

    ROLE_TRANSITIONS = {
        "RESIDENT": [],
        "VOLUNTEER": [("OPEN", "ACTIVE"), ("ACTIVE", "RESOLVED")],
        "SECURITY": [("OPEN", "ACTIVE"), ("ACTIVE", "ESCALATED"), ("ACTIVE", "RESOLVED"), ("ESCALATED", "RESOLVED")],
        "ADMIN": [
            ("OPEN", "ACTIVE"),
            ("ACTIVE", "ESCALATED"),
            ("ACTIVE", "RESOLVED"),
            ("ESCALATED", "RESOLVED"),
            ("RESOLVED", "CLOSED"),
        ],
        "STAFF": [
            ("OPEN", "ACTIVE"),
            ("ACTIVE", "ESCALATED"),
            ("ACTIVE", "RESOLVED"),
            ("ESCALATED", "RESOLVED"),
            ("RESOLVED", "CLOSED"),
        ],
    }

    @classmethod
    def get_allowed_next_states(cls, current_status: str, role: str) -> list:
        current_state = cls.STATUS_MAP.get(current_status, "OPEN")
        possible_next = cls.LIFECYCLE_TRANSITIONS.get(current_state, [])
        role_allowed = cls.ROLE_TRANSITIONS.get(role, [])
        allowed = []
        for next_st in possible_next:
            if (current_state, next_st) in role_allowed:
                allowed.append(next_st)
        return allowed

    @classmethod
    def transition_status(
        cls,
        incident_id: int,
        new_status: str,
        user,
        remarks: str = None,
        ip_address: str = None
    ) -> SOSIncident:
        with transaction.atomic():
            try:
                incident = SOSIncident.objects.select_for_update().select_related("resident", "category").get(pk=incident_id)
            except SOSIncident.DoesNotExist:
                raise ValueError("Incident not found.")

            old_state = cls.STATUS_MAP.get(incident.current_status, cls.STATUS_MAP.get(incident.status, "OPEN"))
            target_state = cls.STATUS_MAP.get(new_status, new_status.upper())

            if old_state == "CLOSED":
                raise ValueError("Incident is CLOSED and cannot transition anywhere.")

            if target_state not in cls.LIFECYCLE_TRANSITIONS.get(old_state, []):
                raise ValueError(f"Invalid transition from '{old_state}' to '{target_state}'. Allowed next states: {cls.LIFECYCLE_TRANSITIONS.get(old_state, [])}")

            role = getattr(user, 'role', 'RESIDENT')
            allowed_for_role = cls.ROLE_TRANSITIONS.get(role, [])
            if (old_state, target_state) not in allowed_for_role:
                raise PermissionError(f"Role '{role}' is not authorized to transition incident from '{old_state}' to '{target_state}'.")

            now = timezone.now()
            incident.current_status = target_state

            # Sync legacy status field
            legacy_map = {
                "OPEN": "Pending",
                "ACTIVE": "In Progress",
                "ESCALATED": "Escalated",
                "RESOLVED": "Resolved",
                "CLOSED": "Closed",
            }
            incident.status = legacy_map.get(target_state, target_state)

            if target_state == "ACTIVE":
                incident.active_at = now
            elif target_state == "ESCALATED":
                incident.escalated_at = now
            elif target_state == "RESOLVED":
                incident.resolved_at = now
                incident.resolved_by = user
            elif target_state == "CLOSED":
                incident.closed_at = now
                incident.closed_by = user

            incident.save()

            # Record audit log
            IncidentStatusLog.objects.create(
                incident=incident,
                old_status=old_state,
                new_status=target_state,
                changed_by=user,
                role=role,
                remarks=remarks or f"Status transitioned to {target_state}",
                ip_address=ip_address
            )

            # Notification triggering
            cls._notify_lifecycle_change(incident, old_state, target_state, user)

            try:
                actor_name = getattr(user, 'full_name', 'System')
                IncidentChatService.create_system_message(
                    incident,
                    f"Incident status updated to {target_state} by {actor_name}."
                )
            except Exception as chat_err:
                print(f"[IncidentLifecycleService] System chat message error: {chat_err}")

            return incident

    @classmethod
    def close_incident(
        cls,
        incident_id: int,
        user,
        resolution_summary: str,
        closure_notes: str,
        closure_reason: str,
        attachments=None,
        ip_address: str = None
    ) -> SOSIncident:
        with transaction.atomic():
            try:
                incident = SOSIncident.objects.select_for_update().select_related("resident", "category").get(pk=incident_id)
            except SOSIncident.DoesNotExist:
                raise ValueError("Incident not found.")

            current_state = cls.STATUS_MAP.get(incident.current_status, cls.STATUS_MAP.get(incident.status, "OPEN"))

            if current_state != "RESOLVED":
                raise ValueError(f"Only incidents in 'RESOLVED' state can be closed. Current state is '{current_state}'.")

            role = getattr(user, 'role', 'RESIDENT')
            if role not in ["ADMIN", "STAFF", "VOLUNTEER", "SECURITY"]:
                raise PermissionError(f"Role '{role}' is not authorized to close incidents.")

            now = timezone.now()
            incident.current_status = "CLOSED"
            incident.status = "Closed"
            incident.closed_at = now
            incident.closed_by = user
            incident.resolution_summary = resolution_summary
            incident.closure_notes = closure_notes
            incident.closure_reason = closure_reason

            incident.save()

            IncidentStatusLog.objects.create(
                incident=incident,
                old_status="RESOLVED",
                new_status="CLOSED",
                changed_by=user,
                role=role,
                remarks=f"Closure: {closure_reason}. {closure_notes or ''}".strip(),
                ip_address=ip_address
            )

            cls._notify_lifecycle_change(incident, "RESOLVED", "CLOSED", user)

            try:
                actor_name = getattr(user, 'full_name', 'System')
                IncidentChatService.create_system_message(
                    incident,
                    f"Incident closed by {actor_name}. Reason: {closure_reason}."
                )
            except Exception as chat_err:
                print(f"[IncidentLifecycleService] System chat message error: {chat_err}")

            return incident

    @classmethod
    def get_incident_timeline(cls, incident_id: int) -> list:
        try:
            incident = SOSIncident.objects.select_related("resident", "assigned_responder").get(pk=incident_id)
        except SOSIncident.DoesNotExist:
            return []

        timeline = []

        # 1. Open Event
        open_time = incident.opened_at or incident.created_at
        timeline.append({
            "status": "OPEN",
            "time": open_time.isoformat() if open_time else None,
            "user": incident.resident.id if incident.resident else None,
            "user_name": incident.resident.full_name if incident.resident else "Resident",
            "role": "RESIDENT",
            "remarks": f"Emergency SOS triggered: {incident.message or 'Immediate assistance required.'}"
        })

        # 2. Acceptance Event if exists
        if incident.accepted_at and incident.assigned_responder:
            timeline.append({
                "status": "ACCEPTED",
                "time": incident.accepted_at.isoformat(),
                "user": incident.assigned_responder.id,
                "user_name": incident.assigned_responder.full_name,
                "role": incident.assigned_role or "RESPONDER",
                "remarks": f"Emergency accepted by {incident.assigned_role or 'Responder'} {incident.assigned_responder.full_name}"
            })

        # 3. Status Change Logs
        logs = IncidentStatusLog.objects.filter(incident_id=incident_id).select_related("changed_by").order_by("timestamp")
        for l in logs:
            user_name = l.changed_by.full_name if l.changed_by else "System"
            timeline.append({
                "status": l.new_status,
                "time": l.timestamp.isoformat(),
                "user": l.changed_by.id if l.changed_by else None,
                "user_name": user_name,
                "role": l.role or "SYSTEM",
                "remarks": l.remarks or f"Transitioned from {l.old_status} to {l.new_status}"
            })

        return timeline

    @classmethod
    def _notify_lifecycle_change(cls, incident: SOSIncident, old_status: str, new_status: str, actor):
        resident = incident.resident
        User = get_user_model()

        recipients = [resident]

        if incident.assigned_responder:
            recipients.append(incident.assigned_responder)

        admins_and_security = User.objects.filter(role__in=["ADMIN", "SECURITY"])
        recipients.extend(list(admins_and_security))

        unique_recipients = {r.id: r for r in recipients if r and r.id != getattr(actor, 'id', None)}.values()

        actor_name = getattr(actor, 'full_name', 'System')
        msg = f"SOS Incident #{incident.id} updated from {old_status} to {new_status} by {actor_name}."

        for user in unique_recipients:
            try:
                NotificationEngineService.dispatch_notification(
                    user=user,
                    title=f"SOS Lifecycle Update: {new_status}",
                    message=msg,
                    category="sos",
                    incident=incident
                )
            except Exception as ex:
                print(f"[IncidentLifecycleService] Error dispatching notification to {user}: {ex}")

        # Send SMS to Primary Guardians
        try:
            from emergency.models import Guardian
            guardians = Guardian.objects.filter(resident=resident, is_primary=True)
            for g in guardians:
                if g.phone:
                    try:
                        NotificationEngineService.send_sms(
                            phone=g.phone,
                            message=f"SOS Alert Update: Incident #{incident.id} is now {new_status}."
                        )
                    except Exception as sms_err:
                        print(f"[IncidentLifecycleService] Guardian SMS error: {sms_err}")
        except Exception as e:
            print(f"[IncidentLifecycleService] Guardian notification exception: {e}")


class IncidentChatService:
    @classmethod
    def is_participant(cls, incident: SOSIncident, user) -> bool:
        if not user or not user.is_authenticated:
            return False

        role = getattr(user, 'role', 'RESIDENT')
        if role in ['ADMIN', 'STAFF'] or getattr(user, 'is_staff', False):
            return True

        if incident.resident_id == user.id:
            return True

        if incident.assigned_responder_id == user.id:
            return True

        if AssignmentLog.objects.filter(incident=incident, responder=user).exists():
            return True

        from emergency.models import Guardian
        if Guardian.objects.filter(resident=incident.resident, phone=getattr(user, 'phone_number', '')).exists():
            return True

        return False

    @classmethod
    def create_system_message(cls, incident: SOSIncident, text: str) -> IncidentChatMessage:
        msg = IncidentChatMessage.objects.create(
            incident=incident,
            sender=None,
            sender_role='SYSTEM',
            message_type='SYSTEM',
            message=text
        )
        cls.broadcast_message(msg)
        return msg

    @classmethod
    def create_chat_message(
        cls,
        incident: SOSIncident,
        sender,
        message: str = "",
        message_type: str = "TEXT",
        attachment=None,
        latitude=None,
        longitude=None,
        reply_to=None
    ) -> IncidentChatMessage:
        current_st = incident.current_status or incident.status
        if current_st in ["CLOSED", "Closed"]:
            raise ValueError("Incident is closed. Chat is read-only.")

        if not cls.is_participant(incident, sender):
            raise PermissionError("Only authorized incident participants may send messages.")

        role = getattr(sender, 'role', 'RESIDENT')
        if incident.resident_id == sender.id:
            sender_role = 'RESIDENT'
        elif incident.assigned_responder_id == sender.id:
            sender_role = role
        elif role in ['ADMIN', 'STAFF']:
            sender_role = 'ADMIN'
        else:
            from emergency.models import Guardian
            if Guardian.objects.filter(resident=incident.resident, phone=getattr(sender, 'phone_number', '')).exists():
                sender_role = 'GUARDIAN'
            else:
                sender_role = role

        msg = IncidentChatMessage.objects.create(
            incident=incident,
            sender=sender,
            sender_role=sender_role,
            message=message or "",
            message_type=message_type,
            attachment=attachment,
            latitude=latitude,
            longitude=longitude,
            reply_to=reply_to
        )

        cls.broadcast_message(msg)
        cls.notify_new_message(msg)
        return msg

    @classmethod
    def broadcast_message(cls, chat_msg: IncidentChatMessage):
        try:
            from channels.layers import get_channel_layer
            from asgiref.sync import async_to_sync

            channel_layer = get_channel_layer()
            if not channel_layer:
                return

            attachment_url = None
            if chat_msg.attachment:
                try:
                    attachment_url = chat_msg.attachment.url
                except Exception:
                    attachment_url = str(chat_msg.attachment)

            payload = {
                "type": "chat_message_broadcast",
                "message": {
                    "id": chat_msg.id,
                    "incident_id": chat_msg.incident_id,
                    "sender_id": chat_msg.sender_id,
                    "sender_name": chat_msg.sender.full_name if chat_msg.sender else "SYSTEM",
                    "sender_role": chat_msg.sender_role,
                    "message": chat_msg.message,
                    "message_type": chat_msg.message_type,
                    "attachment": attachment_url,
                    "latitude": float(chat_msg.latitude) if chat_msg.latitude else None,
                    "longitude": float(chat_msg.longitude) if chat_msg.longitude else None,
                    "is_read": chat_msg.is_read,
                    "reply_to_id": chat_msg.reply_to_id,
                    "created_at": chat_msg.created_at.isoformat(),
                }
            }

            async_to_sync(channel_layer.group_send)(
                f"incident_chat_{chat_msg.incident_id}",
                payload
            )
        except Exception as e:
            print(f"[IncidentChatService] Broadcast exception: {e}")

    @classmethod
    def notify_new_message(cls, chat_msg: IncidentChatMessage):
        if chat_msg.message_type == 'SYSTEM' or not chat_msg.sender:
            return

        incident = chat_msg.incident
        sender = chat_msg.sender
        sender_name = sender.full_name or sender.email

        recipients = []

        if incident.resident and incident.resident_id != sender.id:
            recipients.append(incident.resident)

        if incident.assigned_responder and incident.assigned_responder_id != sender.id:
            recipients.append(incident.assigned_responder)

        for r in set(recipients):
            try:
                NotificationEngineService.dispatch_notification(
                    user=r,
                    title=f"New Chat Message from {sender_name}",
                    message=chat_msg.message[:100] if chat_msg.message else f"Sent a {chat_msg.message_type} message.",
                    category="sos_chat",
                    incident=incident
                )
            except Exception as e:
                print(f"[IncidentChatService] Notification error: {e}")


class IncidentResponseUpdateService:
    @classmethod
    def create_system_update(cls, incident: SOSIncident, update_type: str, message: str) -> IncidentResponseUpdate:
        update = IncidentResponseUpdate.objects.create(
            incident=incident,
            author=None,
            role='SYSTEM',
            update_type=update_type,
            message=message,
            visibility='PUBLIC'
        )
        cls.broadcast_response_update(update)
        return update

    @classmethod
    def create_response_update(
        cls,
        incident: SOSIncident,
        author,
        update_type: str = 'TEXT',
        message: str = '',
        visibility: str = 'PUBLIC',
        attachment=None,
        latitude=None,
        longitude=None
    ) -> IncidentResponseUpdate:
        current_st = incident.current_status or incident.status
        if current_st in ['CLOSED', 'Closed']:
            raise ValueError("Incident is closed. Updates are read-only.")

        if not IncidentChatService.is_participant(incident, author):
            raise PermissionError("Only incident participants can post response updates.")

        role = getattr(author, 'role', 'RESIDENT')
        if incident.resident_id == author.id:
            author_role = 'RESIDENT'
        elif incident.assigned_responder_id == author.id:
            author_role = role
        elif role in ['ADMIN', 'STAFF']:
            author_role = 'ADMIN'
        else:
            author_role = role

        update = IncidentResponseUpdate.objects.create(
            incident=incident,
            author=author,
            role=author_role,
            update_type=update_type,
            message=message,
            visibility=visibility,
            attachment=attachment,
            latitude=latitude,
            longitude=longitude
        )

        cls.notify_response_update(update)
        cls.broadcast_response_update(update)
        return update

    @classmethod
    def broadcast_response_update(cls, update: IncidentResponseUpdate):
        try:
            from channels.layers import get_channel_layer
            from asgiref.sync import async_to_sync
            from .serializers import IncidentResponseUpdateSerializer

            channel_layer = get_channel_layer()
            if channel_layer:
                serializer = IncidentResponseUpdateSerializer(update)
                async_to_sync(channel_layer.group_send)(
                    f"incident_chat_{update.incident_id}",
                    {
                        "type": "response_update_broadcast",
                        "update": serializer.data
                    }
                )
        except Exception as e:
            print(f"[IncidentResponseUpdateService] WebSocket broadcast error: {e}")

    @classmethod
    def notify_response_update(cls, update: IncidentResponseUpdate):
        if update.update_type == 'SYSTEM' or not update.author:
            return

        incident = update.incident
        author_name = update.author.full_name or update.author.email

        recipients = []
        if incident.resident and incident.resident_id != update.author_id:
            recipients.append(incident.resident)
        if incident.assigned_responder and incident.assigned_responder_id != update.author_id:
            recipients.append(incident.assigned_responder)

        for r in set(recipients):
            try:
                NotificationEngineService.dispatch_notification(
                    user=r,
                    title=f"Incident Update from {author_name}",
                    message=update.message[:100] if update.message else f"New {update.update_type} response update posted.",
                    category="sos",
                    incident=incident
                )
            except Exception as e:
                print(f"[IncidentResponseUpdateService] Notification error: {e}")


