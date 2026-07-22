from django.db import models

from rest_framework import serializers
from .models import User
from django.contrib.auth import authenticate

class RegisterSerializer(serializers.ModelSerializer):
    role = serializers.CharField(required=False, default="RESIDENT")
    
    # Extra inputs for profiles
    society = serializers.IntegerField(required=False, allow_null=True)
    block = serializers.IntegerField(required=False, allow_null=True)
    flat = serializers.IntegerField(required=False, allow_null=True)
    apartment_number = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    relationship = serializers.IntegerField(required=False, allow_null=True)
    skills = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    availability = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    service_area = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    shift = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    employee_id = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    assigned_society = serializers.IntegerField(required=False, allow_null=True)

    class Meta:
        extra_kwargs = {
            "password": {"write_only": True}
        }
        model = User
        fields = [
            "full_name",
            "email",
            "phone_number",
            "password",
            "role",
            "society",
            "block",
            "flat",
            "apartment_number",
            "relationship",
            "skills",
            "availability",
            "service_area",
            "shift",
            "employee_id",
            "assigned_society",
        ]

    def validate(self, attrs):
        email = attrs.get('email')
        phone_number = attrs.get('phone_number')
        password = attrs.get('password')
        role = attrs.get('role', 'RESIDENT').upper()

        if User.objects.filter(email=email).exists():
            raise serializers.ValidationError({"email": "This email is already in use."})
        
        if phone_number and User.objects.filter(phone_number=phone_number).exists():
            raise serializers.ValidationError({"phone_number": "This phone number is already in use."})

        if password and len(password) < 8:
            raise serializers.ValidationError({"password": "Password must be at least 8 characters long."})

        # Required fields check per role
        if role == 'RESIDENT':
            if not attrs.get('society') or not attrs.get('block') or not attrs.get('flat'):
                pass  # We won't block if the UI lets them map it later, but let's log or keep it soft.
        elif role == 'GUARDIAN':
            if not attrs.get('relationship'):
                raise serializers.ValidationError({"relationship": "Relationship is required for Guardian."})
        elif role == 'VOLUNTEER':
            if not attrs.get('skills') or not attrs.get('availability') or not attrs.get('service_area'):
                raise serializers.ValidationError({"volunteer": "Volunteer skills, availability, and service area are required."})
        elif role == 'SECURITY':
            if not attrs.get('shift') or not attrs.get('employee_id') or not attrs.get('assigned_society'):
                raise serializers.ValidationError({"security": "Security shift, employee ID, and assigned society are required."})

        return attrs

    def create(self, validated_data):
        role = validated_data.get("role", "RESIDENT").upper()
        
        # User details
        user = User.objects.create_user(
            username=validated_data["email"],
            full_name=validated_data["full_name"],
            email=validated_data["email"],
            phone_number=validated_data.get("phone_number", ""),
            password=validated_data["password"],
            role=role
        )
        
        # Depending on role, create profile
        from .models import ResidentProfile, VolunteerProfile, SecurityProfile, GuardianProfile
        if role == "RESIDENT":
            from society.models import Society, BlockTower, Flat
            society_id = validated_data.get('society')
            block_id = validated_data.get('block')
            flat_id = validated_data.get('flat')
            
            society = Society.objects.filter(id=society_id).first() if society_id else None
            block = BlockTower.objects.filter(id=block_id).first() if block_id else None
            flat = Flat.objects.filter(id=flat_id).first() if flat_id else None
            
            ResidentProfile.objects.create(
                user=user,
                society=society,
                block=block,
                flat=flat,
                status='Pending'
            )
        elif role == "GUARDIAN":
            from emergency.models import Relationship
            relationship_id = validated_data.get('relationship')
            relationship = Relationship.objects.filter(id=relationship_id).first() if relationship_id else None
            GuardianProfile.objects.create(
                user=user,
                relationship=relationship,
                phone_number=validated_data.get('phone_number', ''),
                email=validated_data.get('email', '')
            )
        elif role == "VOLUNTEER":
            VolunteerProfile.objects.create(
                user=user,
                skills=validated_data.get('skills', ''),
                availability=validated_data.get('availability', ''),
                service_area=validated_data.get('service_area', '')
            )
        elif role == "SECURITY":
            from society.models import Society
            assigned_society_id = validated_data.get('assigned_society')
            assigned_society = Society.objects.filter(id=assigned_society_id).first() if assigned_society_id else None
            SecurityProfile.objects.create(
                user=user,
                shift=validated_data.get('shift', ''),
                employee_id=validated_data.get('employee_id', ''),
                assigned_society=assigned_society
            )
            
        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'email', 'full_name', 'phone_number', 'role']

from .models import ResidentProfile

class ResidentProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    society_name = serializers.ReadOnlyField(source='society.name')
    block_name = serializers.ReadOnlyField(source='block.name')
    flat_number = serializers.ReadOnlyField(source='flat.flat_number')
    approved_by_name = serializers.ReadOnlyField(source='approved_by.full_name')

    class Meta:
        model = ResidentProfile
        fields = '__all__'


from .models import VolunteerProfile

class VolunteerProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = VolunteerProfile
        fields = '__all__'


        