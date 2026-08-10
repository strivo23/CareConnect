"""
sos/serializers.py

Serializers for the SOS module:
  - EmergencyCategorySerializer  — read-only category listing
  - SOSIncidentSerializer        — full read representation
  - SOSSendSerializer            — write-only; used for POST /api/sos/send/
  - SOSStatusUpdateSerializer    — used for PATCH accept/in-progress/resolve/cancel
"""

from decimal import Decimal
from rest_framework import serializers
from .models import EmergencyCategory, SOSIncident, SOSEmergencyMessage, AssignmentLog, IncidentStatusLog, IncidentChatMessage, IncidentResponseUpdate


# ---------------------------------------------------------------------------
# EmergencyCategory
# ---------------------------------------------------------------------------

class EmergencyCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyCategory
        fields = ["id", "name", "icon", "description", "is_active"]


def compute_incident_permissions(incident, user):
    """
    Compute incident-based permission flags for the given authenticated user.
    Permissions depend strictly on the user's relationship to the CURRENT incident:
      - is_sender: True if user is the resident who created the incident.
      - is_assigned_guardian: True if user is an active linked guardian for the resident.
      - is_assigned_volunteer: True if user is a volunteer assigned/available for the incident.
      - is_assigned_security: True if user is security assigned/available for the incident.
      - can_accept, can_decline, can_chat, can_call, can_navigate: Responder permissions.
    Rules:
      1. If user is sender: is_sender = True, all responder permissions are False.
      2. If user is assigned guardian/volunteer/security: responder permissions are True.
      3. Sender MUST NEVER receive responder permissions.
    """
    if not user or not getattr(user, 'is_authenticated', False):
        return {
            "is_sender": False,
            "is_assigned_guardian": False,
            "is_assigned_volunteer": False,
            "is_assigned_security": False,
            "can_accept": False,
            "can_decline": False,
            "can_chat": False,
            "can_call": False,
            "can_navigate": False,
        }

    is_sender = (incident.resident_id == user.id)

    from emergency.models import ResidentGuardian

    # Check if user is active linked guardian for sender
    is_assigned_guardian = ResidentGuardian.objects.filter(
        guardian=user,
        resident=incident.resident,
        status='Active'
    ).exists()

    role_str = str(getattr(user, 'role', '')).upper()
    is_assigned_volunteer = (role_str == "VOLUNTEER") or (incident.assigned_responder_id == user.id and incident.assigned_role == "VOLUNTEER")
    is_assigned_security = (role_str == "SECURITY") or (incident.assigned_responder_id == user.id and incident.assigned_role == "SECURITY")

    if is_sender:
        # Sender must NEVER receive responder permissions
        return {
            "is_sender": True,
            "is_assigned_guardian": False,
            "is_assigned_volunteer": False,
            "is_assigned_security": False,
            "can_accept": False,
            "can_decline": False,
            "can_chat": False,
            "can_call": False,
            "can_navigate": False,
        }

    is_assigned_responder = (incident.assigned_responder_id == user.id)
    is_responder_role = role_str in ["VOLUNTEER", "SECURITY", "ADMIN", "STAFF", "SOCIETY_MANAGER"]

    is_authorized_responder = is_assigned_guardian or is_assigned_volunteer or is_assigned_security or is_assigned_responder or is_responder_role

    status_str = (incident.status or "").upper()
    current_status_str = (incident.current_status or "").upper()
    is_closed_or_resolved = status_str in ["RESOLVED", "CANCELLED", "CLOSED"] or current_status_str in ["RESOLVED", "CLOSED"]

    if not is_authorized_responder or is_closed_or_resolved:
        return {
            "is_sender": False,
            "is_assigned_guardian": is_assigned_guardian,
            "is_assigned_volunteer": is_assigned_volunteer,
            "is_assigned_security": is_assigned_security,
            "can_accept": False,
            "can_decline": False,
            "can_chat": False,
            "can_call": False,
            "can_navigate": False,
        }

    can_accept = status_str in ["PENDING", "OPEN"] and (
        incident.assigned_responder_id is None or incident.assigned_responder_id == user.id
    )

    return {
        "is_sender": False,
        "is_assigned_guardian": is_assigned_guardian,
        "is_assigned_volunteer": is_assigned_volunteer,
        "is_assigned_security": is_assigned_security,
        "can_accept": can_accept,
        "can_decline": True,
        "can_chat": True,
        "can_call": True,
        "can_navigate": True,
    }


# ---------------------------------------------------------------------------
# SOSIncident — read representation
# ---------------------------------------------------------------------------

class SOSIncidentSerializer(serializers.ModelSerializer):
    """Full read serializer returned in list / retrieve / history endpoints."""

    resident_name = serializers.SerializerMethodField()
    resident_email = serializers.EmailField(
        source="resident.email", read_only=True
    )
    category_name = serializers.SerializerMethodField()
    resolved_address = serializers.SerializerMethodField()
    triggered_time = serializers.DateTimeField(
        source="created_at", read_only=True
    )
    assigned_responder_name = serializers.SerializerMethodField()
    resolved_by_name = serializers.SerializerMethodField()
    closed_by_name = serializers.SerializerMethodField()
    allowed_next_statuses = serializers.SerializerMethodField()

    # Permission flags based on user relationship to CURRENT incident
    is_sender = serializers.SerializerMethodField()
    is_assigned_guardian = serializers.SerializerMethodField()
    is_assigned_volunteer = serializers.SerializerMethodField()
    is_assigned_security = serializers.SerializerMethodField()
    can_accept = serializers.SerializerMethodField()
    can_decline = serializers.SerializerMethodField()
    can_chat = serializers.SerializerMethodField()
    can_call = serializers.SerializerMethodField()
    can_navigate = serializers.SerializerMethodField()

    class Meta:
        model = SOSIncident
        fields = [
            "id",
            "resident",
            "resident_name",
            "resident_email",
            "category",
            "category_name",
            "message",
            "emergency_description",
            "voice_message",
            "voice_duration",
            "voice_uploaded_at",
            "latitude",
            "longitude",
            "address",
            "city",
            "state",
            "country",
            "pincode",
            "status",
            "current_status",
            "assigned_responder",
            "assigned_responder_name",
            "assigned_role",
            "accepted_at",
            "assignment_status",
            "opened_at",
            "active_at",
            "escalated_at",
            "resolved_at",
            "closed_at",
            "resolution_summary",
            "closure_reason",
            "closure_notes",
            "resolved_by",
            "resolved_by_name",
            "closed_by",
            "closed_by_name",
            "last_status_changed_at",
            "allowed_next_statuses",
            "resolved_address",
            "priority",
            "created_at",
            "triggered_time",
            "updated_at",
            "is_sender",
            "is_assigned_guardian",
            "is_assigned_volunteer",
            "is_assigned_security",
            "can_accept",
            "can_decline",
            "can_chat",
            "can_call",
            "can_navigate",
        ]
        read_only_fields = fields  # entire serializer is read-only

    def _get_permissions(self, obj):
        if not hasattr(self, "_cached_permissions"):
            self._cached_permissions = {}
        if obj.id not in self._cached_permissions:
            request = self.context.get("request")
            user = getattr(request, "user", None) if request else None
            self._cached_permissions[obj.id] = compute_incident_permissions(obj, user)
        return self._cached_permissions[obj.id]

    def get_is_sender(self, obj):
        return self._get_permissions(obj)["is_sender"]

    def get_is_assigned_guardian(self, obj):
        return self._get_permissions(obj)["is_assigned_guardian"]

    def get_is_assigned_volunteer(self, obj):
        return self._get_permissions(obj)["is_assigned_volunteer"]

    def get_is_assigned_security(self, obj):
        return self._get_permissions(obj)["is_assigned_security"]

    def get_can_accept(self, obj):
        return self._get_permissions(obj)["can_accept"]

    def get_can_decline(self, obj):
        return self._get_permissions(obj)["can_decline"]

    def get_can_chat(self, obj):
        return self._get_permissions(obj)["can_chat"]

    def get_can_call(self, obj):
        return self._get_permissions(obj)["can_call"]

    def get_can_navigate(self, obj):
        return self._get_permissions(obj)["can_navigate"]

    def get_assigned_responder_name(self, obj):
        if obj.assigned_responder:
            name = getattr(obj.assigned_responder, "full_name", None) or obj.assigned_responder.get_full_name()
            return name or obj.assigned_responder.email
        return None

    def get_resolved_by_name(self, obj):
        if obj.resolved_by:
            return getattr(obj.resolved_by, "full_name", None) or obj.resolved_by.email
        return None

    def get_closed_by_name(self, obj):
        if obj.closed_by:
            return getattr(obj.closed_by, "full_name", None) or obj.closed_by.email
        return None

    def get_allowed_next_statuses(self, obj):
        request = self.context.get("request")
        role = request.user.role if (request and hasattr(request, "user") and hasattr(request.user, "role")) else "RESIDENT"
        from .services import IncidentLifecycleService
        return IncidentLifecycleService.get_allowed_next_states(obj.current_status or obj.status, role)

    def get_resident_name(self, obj):
        if obj.resident:
            name = getattr(obj.resident, "full_name", None) or obj.resident.get_full_name()
            if name and name.strip():
                return name.strip()
            if obj.resident.email:
                return obj.resident.email.split("@")[0].capitalize()
        return "Unknown Resident"

    def get_category_name(self, obj):
        if obj.category and obj.category.name:
            return obj.category.name
        return "SOS Emergency"

    def get_resolved_address(self, obj):
        if obj.address and obj.address.strip() and obj.address.strip() not in ["Address not resolved", "Address unavailable"]:
            return obj.address.strip()
        if obj.latitude is not None and obj.longitude is not None:
            from .services import SOSService
            resolved = SOSService.reverse_geocode(obj.latitude, obj.longitude)
            if resolved and resolved != "Location could not be resolved":
                obj.address = resolved
                obj.save(update_fields=["address"])
                return resolved
            return "Location could not be resolved"
        return "Location unavailable"






# ---------------------------------------------------------------------------
# SOSSendSerializer — write serializer for creating a new SOS
# ---------------------------------------------------------------------------

class SOSSendSerializer(serializers.ModelSerializer):
    category = serializers.PrimaryKeyRelatedField(
        queryset=EmergencyCategory.objects.all(),
        required=False,
        allow_null=True
    )


    class Meta:
        model = SOSIncident
        fields = ["category", "message", "emergency_description", "latitude", "longitude", "address", "city", "state", "country", "pincode", "priority"]

    def to_internal_value(self, data):
        if isinstance(data, dict):
            data = data.copy()
            for field in ["latitude", "longitude"]:
                val = data.get(field)
                if val is not None:
                    try:
                        data[field] = round(float(val), 6)
                    except (ValueError, TypeError):
                        pass
        return super().to_internal_value(data)


    def validate(self, attrs):
        if not attrs.get("category"):
            default_cat = EmergencyCategory.objects.filter(is_active=True).first()
            if default_cat:
                attrs["category"] = default_cat
            else:
                raise serializers.ValidationError({"category": "No active emergency category available."})
        return attrs

    def validate_category(self, category):
        if category and not category.is_active:
            raise serializers.ValidationError(
                "This emergency category is currently inactive and cannot be used."
            )
        return category


    def validate_message(self, value):
        if value and len(value) > 500:
            raise serializers.ValidationError(
                "Message cannot exceed 500 characters."
            )
        return value

    def validate_latitude(self, value):
        if value is not None:
            if not (Decimal("-90") <= value <= Decimal("90")):
                raise serializers.ValidationError(
                    "Latitude must be between -90 and 90."
                )
        return value

    def validate_longitude(self, value):
        if value is not None:
            if not (Decimal("-180") <= value <= Decimal("180")):
                raise serializers.ValidationError(
                    "Longitude must be between -180 and 180."
                )
        return value


# ---------------------------------------------------------------------------
# SOSIncidentUpdateSerializer — used for updating SOS incidents via PATCH
# ---------------------------------------------------------------------------

class SOSIncidentUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = SOSIncident
        fields = ["message", "emergency_description", "priority", "status", "latitude", "longitude", "address", "city", "state", "country", "pincode"]

    def validate_message(self, value):
        if value and len(value) > 500:
            raise serializers.ValidationError(
                "Message cannot exceed 500 characters."
            )
        return value

    def validate_latitude(self, value):
        if value is not None:
            if not (Decimal("-90") <= value <= Decimal("90")):
                raise serializers.ValidationError(
                    "Latitude must be between -90 and 90."
                )
        return value

    def validate_longitude(self, value):
        if value is not None:
            if not (Decimal("-180") <= value <= Decimal("180")):
                raise serializers.ValidationError(
                    "Longitude must be between -180 and 180."
                )
        return value


# ---------------------------------------------------------------------------
# SOSEmergencyMessageSerializer
# ---------------------------------------------------------------------------

class SOSEmergencyMessageSerializer(serializers.ModelSerializer):
    sender_email = serializers.EmailField(source="sender.email", read_only=True)

    class Meta:
        model = SOSEmergencyMessage
        fields = ["id", "incident", "sender", "sender_email", "message", "created_at"]
        read_only_fields = ["id", "incident", "sender", "sender_email", "created_at"]

    def validate_message(self, value):
        if not value or not value.strip():
            raise serializers.ValidationError("Message cannot be empty.")
        if len(value) > 500:
            raise serializers.ValidationError("Message cannot exceed 500 characters.")
        return value


class SOSIncidentMessageUploadSerializer(serializers.Serializer):
    """
    Serializer for POST /api/sos/<id>/message/
    Accepts text only (emergency_description or message), voice only (voice_message), or both. Rejects empty requests.
    """
    emergency_description = serializers.CharField(required=False, allow_blank=True)
    message = serializers.CharField(required=False, allow_blank=True)
    voice_message = serializers.FileField(required=False, allow_null=True, default=None)
    voice_duration = serializers.IntegerField(required=False, allow_null=True, default=None)


    def validate(self, attrs):
        description = attrs.get("emergency_description") or attrs.get("message") or ""
        attrs["emergency_description"] = description
        voice = attrs.get("voice_message")

        has_text = bool(description and description.strip())
        has_voice = bool(voice)

        if not has_text and not has_voice:
            raise serializers.ValidationError(
                "Either emergency description or voice message must be provided."
            )
        return attrs




# ---------------------------------------------------------------------------
# SOSStatusUpdateSerializer — used for status-change PATCH actions
# ---------------------------------------------------------------------------

class SOSStatusUpdateSerializer(serializers.Serializer):
    """
    Minimal serializer used by accept / in-progress / resolve / cancel actions.
    No body fields are required; the target status is determined by the endpoint.
    An optional 'note' field can be added in the future for audit trails.
    """

    note = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=500,
        help_text="Optional note to accompany the status change.",
    )


from .models import EscalationConfig, EscalationLog

class EscalationConfigSerializer(serializers.ModelSerializer):
    class Meta:
        model = EscalationConfig
        fields = '__all__'


class EscalationLogSerializer(serializers.ModelSerializer):
    resident_name = serializers.CharField(source="incident.resident.full_name", read_only=True)
    category_name = serializers.CharField(source="incident.category.name", read_only=True)

    class Meta:
        model = EscalationLog
        fields = '__all__'


class SOSRejectSerializer(serializers.Serializer):
    reason = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=500,
        help_text="Optional reason for rejecting the SOS alert.",
    )


from .models import AssignmentLog, IncidentStatusLog

class AssignmentLogSerializer(serializers.ModelSerializer):
    responder_name = serializers.CharField(source="responder.full_name", read_only=True)
    responder_email = serializers.EmailField(source="responder.email", read_only=True)

    class Meta:
        model = AssignmentLog
        fields = [
            "id",
            "incident",
            "responder",
            "responder_name",
            "responder_email",
            "role",
            "accepted_at",
            "previous_status",
            "new_status",
            "ip_address",
            "created_at",
        ]


class IncidentStatusLogSerializer(serializers.ModelSerializer):
    changed_by_name = serializers.SerializerMethodField()

    class Meta:
        model = IncidentStatusLog
        fields = [
            "id",
            "incident",
            "old_status",
            "new_status",
            "changed_by",
            "changed_by_name",
            "role",
            "timestamp",
            "remarks",
            "ip_address",
        ]

    def get_changed_by_name(self, obj):
        if obj.changed_by:
            return getattr(obj.changed_by, "full_name", None) or obj.changed_by.email
        return "System"


class IncidentChatMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.SerializerMethodField()
    reply_to_detail = serializers.SerializerMethodField()

    class Meta:
        model = IncidentChatMessage
        fields = [
            "id",
            "incident",
            "sender",
            "sender_name",
            "sender_role",
            "message",
            "message_type",
            "attachment",
            "latitude",
            "longitude",
            "is_read",
            "is_deleted",
            "reply_to",
            "reply_to_detail",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "sender", "sender_role", "created_at", "updated_at"]

    def get_sender_name(self, obj):
        if obj.sender:
            return getattr(obj.sender, "full_name", None) or obj.sender.email
        return "SYSTEM"

    def get_reply_to_detail(self, obj):
        if obj.reply_to:
            sender_name = getattr(obj.reply_to.sender, "full_name", None) if obj.reply_to.sender else "SYSTEM"
            return {
                "id": obj.reply_to.id,
                "sender_name": sender_name,
                "message": obj.reply_to.message,
                "message_type": obj.reply_to.message_type,
            }
        return None


class IncidentResponseUpdateSerializer(serializers.ModelSerializer):
    author_name = serializers.SerializerMethodField()

    class Meta:
        model = IncidentResponseUpdate
        fields = [
            "id",
            "incident",
            "author",
            "author_name",
            "role",
            "update_type",
            "message",
            "visibility",
            "attachment",
            "latitude",
            "longitude",
            "created_at",
        ]
        read_only_fields = ["id", "author", "role", "created_at"]

    def get_author_name(self, obj):
        if obj.author:
            return getattr(obj.author, "full_name", None) or obj.author.email
        return "SYSTEM"


from .models import BroadcastLog

class BroadcastLogSerializer(serializers.ModelSerializer):
    resident_name = serializers.CharField(source="incident.resident.full_name", read_only=True)
    category_name = serializers.CharField(source="incident.category.name", read_only=True)

    class Meta:
        model = BroadcastLog
        fields = '__all__'



