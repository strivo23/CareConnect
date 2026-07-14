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

    resident_name = serializers.CharField(
        source="resident.full_name", read_only=True
    )
    resident_email = serializers.EmailField(
        source="resident.email", read_only=True
    )
    category_name = serializers.CharField(
        source="category.name", read_only=True
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
            "priority",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields  # entire serializer is read-only


# ---------------------------------------------------------------------------
# SOSSendSerializer — write serializer for creating a new SOS
# ---------------------------------------------------------------------------

class SOSSendSerializer(serializers.ModelSerializer):
    """
    Used for POST /api/sos/send/.
    Validates:
      - category must be active
      - latitude   -90   to  90
      - longitude  -180  to 180
      - message    max 500 characters
    """

    class Meta:
        model = SOSIncident
        fields = ["category", "message", "latitude", "longitude", "address", "priority"]

    def validate_category(self, category):
        if not category.is_active:
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