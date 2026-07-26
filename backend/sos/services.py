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
from .models import SOSIncident, EmergencyCategory, EscalationConfig, EscalationLog
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

# Valid status transitions: current_status -> allowed_next_statuses
STATUS_TRANSITIONS = {
    "Pending":     ["Accepted", "Cancelled"],
    "Accepted":    ["In Progress", "Cancelled"],
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
    def reverse_geocode(latitude, longitude) -> str:
        """
        Reverse geocodes (lat, lon) to a readable address using Nominatim API.
        Includes retry logic and returns 'Location could not be resolved' on failure.
        """
        if latitude is None or longitude is None:
            return "Location could not be resolved"
            
        import sys
        if 'test' in sys.argv:
            return f"Mock Street, {latitude}, {longitude}, Test City, Test State, 123456, India"

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
                    if addr:
                        parts = []
                        street = addr.get("road") or addr.get("house_number") or addr.get("pedestrian") or addr.get("suburb")
                        if street:
                            parts.append(street)
                        area = addr.get("neighbourhood") or addr.get("residential") or addr.get("subdistrict") or addr.get("county")
                        if area and area not in parts:
                            parts.append(area)
                        city = addr.get("city") or addr.get("town") or addr.get("village") or addr.get("city_district")
                        if city and city not in parts:
                            parts.append(city)
                        state = addr.get("state")
                        if state and state not in parts:
                            parts.append(state)
                        postcode = addr.get("postcode")
                        if postcode and postcode not in parts:
                            parts.append(postcode)
                        country = addr.get("country")
                        if country and country not in parts:
                            parts.append(country)

                        if parts:
                            return ", ".join(parts)

                    display_name = data.get("display_name")
                    if display_name:
                        return display_name
            except Exception as e:
                print(f"[REVERSE GEOCODE] Attempt {attempt+1} failed: {e}", flush=True)

        return "Location could not be resolved"

    @staticmethod
    def create_incident(user, validated_data: dict) -> SOSIncident:
        """
        Create a new SOS incident for *user*.

        - Forces status = 'Pending'
        - Creates an 'Emergency Alert Received' notification for the resident
        - Notifies primary guardian immediately
        - Schedules escalation steps
        """
        validated_data["resident"] = user
        validated_data["status"] = "Pending"

        # Reverse geocode if coordinates are present and address not supplied or placeholder
        addr_val = validated_data.get("address")
        if (not addr_val or addr_val in ["Address not resolved", "Address unavailable", "Location unavailable", ""]) and validated_data.get("latitude") is not None and validated_data.get("longitude") is not None:
            validated_data["address"] = SOSService.reverse_geocode(
                validated_data["latitude"], validated_data["longitude"]
            )


        with transaction.atomic():
            incident = SOSIncident.objects.create(**validated_data)
            
            # Log SOS Created
            print("SOS Created")

            # Auto-create notification for the resident
            Notification.objects.create(
                user=user,
                title="Emergency Alert Received",
                message=(
                    f"Your SOS incident ({incident.category.name}) has been received "
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

            # Dispatch via central NotificationDispatcher
            NotificationDispatcher.dispatch_sos_created(incident)
            SOSService._notify_primary_guardians(incident)
            notify_guardians(incident)

            # Notify nearby volunteers if coordinates are available
            if incident.latitude is not None and incident.longitude is not None and config.notify_volunteers:
                from accounts.models import VolunteerProfile
                volunteers = VolunteerProfile.objects.filter(is_online=True, latitude__isnull=False, longitude__isnull=False).select_related('user')
                for vol in volunteers:
                    dist = haversine(incident.latitude, incident.longitude, vol.latitude, vol.longitude)
                    if dist <= vol.visibility_radius:
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

        # Immediately run pending escalations process
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

    _daemon_started = False

    @classmethod
    def start_escalation_daemon(cls):
        """Starts a background daemon thread that checks for pending escalations."""
        if cls._daemon_started:
            return
        
        cls._daemon_started = True
        
        def run_loop():
            print("[ESCALATION DAEMON] Background worker started successfully.")
            while True:
                try:
                    SOSService.process_pending_escalations()
                except Exception as e:
                    print(f"[ESCALATION DAEMON] Error in background worker execution: {e}")
                time.sleep(3)  # poll every 3 seconds

        thread = threading.Thread(target=run_loop, daemon=True)
        thread.start()
