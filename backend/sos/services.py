"""
sos/services.py

Business-logic service layer for the SOS module.
Keeps views thin and logic reusable/testable.
"""

from django.utils import timezone
from notifications.models import Notification
from .models import SOSIncident, EmergencyCategory


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
        """
        if latitude is None or longitude is None:
            return ""
        import requests
        try:
            url = "https://nominatim.openstreetmap.org/reverse"
            params = {
                "lat": str(latitude),
                "lon": str(longitude),
                "format": "json"
            }
            headers = {
                "User-Agent": "CareConnectApp/1.0 (contact: admin@careconnect.com)"
            }
            response = requests.get(url, params=params, headers=headers, timeout=5)
            if response.status_code == 200:
                data = response.json()
                return data.get("display_name", "")
        except Exception as e:
            print(f"Geocoding error: {e}")
        return ""

    @staticmethod
    def create_incident(user, validated_data: dict) -> SOSIncident:
        """
        Create a new SOS incident for *user*.

        - Forces status = 'Pending'
        - Creates an 'Emergency Alert Received' notification for the resident
        """
        validated_data["resident"] = user
        validated_data["status"] = "Pending"

        # Reverse geocode if coordinates are present and address not supplied
        if not validated_data.get("address") and validated_data.get("latitude") is not None and validated_data.get("longitude") is not None:
            validated_data["address"] = SOSService.reverse_geocode(
                validated_data["latitude"], validated_data["longitude"]
            )

        incident = SOSIncident.objects.create(**validated_data)
        
        # Log SOS Created
        print("SOS Created")

        # Auto-create notification for the resident
        Notification.objects.create(
            user=user,
            title="🚨 Emergency Alert Received",
            message=(
                f"Your SOS incident ({incident.category.name}) has been received "
                f"and is being processed. Status: Pending."
            ),
            category="sos",
        )

        # Notify guardians
        from django.db.models import Q
        from django.contrib.auth import get_user_model
        from emergency.models import EmergencyContact

        # Query all primary or verified emergency contacts for this resident
        contacts = EmergencyContact.objects.filter(resident=user).filter(
            Q(is_primary=True) | Q(verified=True)
        )
        
        phones = list(contacts.values_list('phone', flat=True))
        
        # Find registered users who match the contact phone numbers (excluding the resident themselves)
        User = get_user_model()
        guardians = User.objects.filter(phone_number__in=phones).exclude(id=user.id)
        
        loc_str = ""
        if incident.latitude is not None and incident.longitude is not None:
            loc_str = f"{incident.latitude}, {incident.longitude}"
            if incident.address:
                loc_str = f"{loc_str} ({incident.address})"

        for guardian in guardians:
            print("Guardian Found")
            # Create Notification with High Priority
            Notification.objects.create(
                user=guardian,
                title="Emergency SOS",
                message=f"{user.full_name} needs immediate assistance.",
                category="sos",
                priority="HIGH",
                location=loc_str,
                incident=incident,
                is_read=False
            )
            print("Notification Created")
            print("Notification Sent")

        return incident

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

        incident.status = new_status
        incident.save(update_fields=["status", "updated_at"])

        # Notify the resident about the status change
        Notification.objects.create(
            user=incident.resident,
            title=f"SOS Update — {new_status}",
            message=(
                f"Your SOS incident ({incident.category.name}) status has been "
                f"updated to '{new_status}'."
            ),
            category="sos",
        )

        return incident
