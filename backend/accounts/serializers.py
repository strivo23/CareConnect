from django.db import models

from rest_framework import serializers
from .models import User
from django.contrib.auth import authenticate

class RegisterSerializer(serializers.ModelSerializer):
    role = serializers.CharField(required=False, default="RESIDENT")

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
            "role"
        ]

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data["email"],
            full_name=validated_data["full_name"],
            email=validated_data["email"],
            phone_number=validated_data["phone_number"],
            password=validated_data["password"],
            role=validated_data.get("role", "RESIDENT")
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

        