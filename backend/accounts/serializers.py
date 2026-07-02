from django.db import models

from rest_framework import serializers
from .models import User

class RegisterSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            "full_name",
            "email",
            "phone_number",
            "password",
        ]

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data["email"],
            full_name=validated_data["full_name"],
            email=validated_data["email"],
            phone_number=validated_data["phone_number"],
            password=validated_data["password"],
        )
        return user
    


        