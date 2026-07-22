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
from .models import EmergencyCategory, SOSIncident, SOSEmergencyMessage


# ---------------------------------------------------------------------------
# EmergencyCategory
# ---------------------------------------------------------------------------

class EmergencyCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyCategory
        fields = ["id", "name", "icon", "description", "is_active"]


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
            "latitude",
            "longitude",
            "status",
            "address",
            "resolved_address",
            "priority",
            "created_at",
            "triggered_time",
            "updated_at",
        ]
        read_only_fields = fields  # entire serializer is read-only

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
        fields = ["category", "message", "latitude", "longitude", "address", "priority"]

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
        fields = ["message", "priority", "status", "latitude", "longitude", "address"]

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
    class Meta:
        model = EscalationLog
        fields = '__all__'