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

    class Meta:
        model = EmergencyContact
        fields = '__all__'
