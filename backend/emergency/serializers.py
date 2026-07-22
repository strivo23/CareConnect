from rest_framework import serializers
from .models import Relationship, VerificationStatus, Guardian, EmergencyContact
from accounts.serializers import UserSerializer

class RelationshipSerializer(serializers.ModelSerializer):
    class Meta:
        model = Relationship
        fields = '__all__'

class VerificationStatusSerializer(serializers.ModelSerializer):
    class Meta:
        model = VerificationStatus
        fields = '__all__'

class GuardianSerializer(serializers.ModelSerializer):
    relationship_name = serializers.ReadOnlyField(source='relationship.name')
    resident_details = UserSerializer(source='resident', read_only=True)

    class Meta:
        model = Guardian
        fields = '__all__'

class EmergencyContactSerializer(serializers.ModelSerializer):
    relationship_name = serializers.ReadOnlyField(source='relationship.name')
    verification_status_details = VerificationStatusSerializer(source='verification_status', read_only=True)
    resident_details = UserSerializer(source='resident', read_only=True)
    
    from django.contrib.auth import get_user_model
    resident = serializers.PrimaryKeyRelatedField(
        queryset=get_user_model().objects.all(),
        required=False,
        allow_null=True
    )

    class Meta:
        model = EmergencyContact
        fields = '__all__'

    def validate(self, data):
        phone = data.get('phone')
        email = data.get('email')
        is_primary = data.get('is_primary', False)
        
        # Determine resident (either explicitly passed or from the request user)
        request = self.context.get('request')
        resident = data.get('resident')
        if not resident and request and request.user.is_authenticated:
            resident = request.user
            
        if not resident:
            raise serializers.ValidationError({"resident": "Resident is required."})

        # Phone format validation (digits, minimum length of 10)
        if phone:
            clean_phone = ''.join(c for c in phone if c.isdigit())
            if len(clean_phone) < 10:
                raise serializers.ValidationError({"phone": "Phone number must contain at least 10 digits."})

        # Email format validation
        if email:
            from django.core.validators import validate_email
            from django.core.exceptions import ValidationError
            try:
                validate_email(email)
            except ValidationError:
                raise serializers.ValidationError({"email": "Enter a valid email address."})

        # Check single primary guardian constraint
        if is_primary:
            queryset = EmergencyContact.objects.filter(resident=resident, is_primary=True)
            if self.instance:
                queryset = queryset.exclude(pk=self.instance.pk)
            if queryset.exists():
                raise serializers.ValidationError({"is_primary": "A resident can only have one primary guardian."})

        return data


class ResidentGuardianSerializer(serializers.ModelSerializer):
    guardian_name = serializers.ReadOnlyField(source='guardian.full_name')
    guardian_email = serializers.ReadOnlyField(source='guardian.email')
    guardian_phone = serializers.ReadOnlyField(source='guardian.phone_number')
    resident_name = serializers.ReadOnlyField(source='resident.full_name')
    resident_email = serializers.ReadOnlyField(source='resident.email')
    resident_phone = serializers.ReadOnlyField(source='resident.phone_number')
    relationship_name = serializers.SerializerMethodField()

    class Meta:
        from .models import ResidentGuardian
        model = ResidentGuardian
        fields = [
            'id',
            'resident',
            'resident_name',
            'resident_email',
            'resident_phone',
            'guardian',
            'guardian_name',
            'guardian_email',
            'guardian_phone',
            'relationship',
            'relationship_name',
            'is_primary',
            'status',
            'linked_at',
            'updated_at',
        ]

    def get_relationship_name(self, obj):
        if obj.relationship:
            return obj.relationship.name
        return obj.relationship_name or "Guardian"


class LinkGuardianSerializer(serializers.Serializer):
    guardian_code = serializers.CharField(max_length=20, required=True)
    relationship = serializers.CharField(max_length=50, required=False, allow_blank=True, default="Guardian")
    is_primary = serializers.BooleanField(default=False)


class RespondLinkSerializer(serializers.Serializer):
    link_id = serializers.IntegerField(required=True)
    action = serializers.ChoiceField(choices=['accept', 'reject'], required=True)


class ChangePrimarySerializer(serializers.Serializer):
    guardian_id = serializers.IntegerField(required=True)


