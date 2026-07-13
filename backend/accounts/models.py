from django.db import models
from django.contrib.auth.models import AbstractUser
from django.conf import settings
from society.models import Society, BlockTower, Flat

class User(AbstractUser):
    ROLE_CHOICES = [
        ("SOCIETY_MANAGER", "Society Manager"),
        ("RESIDENT", "Resident"),
        ("VOLENTEER", "Volenteer"),
        ("SECURITY", "Security")
    ]
    email = models.EmailField(unique=True)
    full_name = models.CharField(max_length=255, blank=True)
    phone_number = models.CharField(max_length=20, blank=True)
    role = models.CharField(max_length=30, choices=ROLE_CHOICES, default="RESIDENT")

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["username"]

    def __str__(self):
        return self.email

class ResidentProfile(models.Model):
    STATUS_CHOICES = [
        ("Pending", "Pending"),
        ("Approved", "Approved"),
        ("Rejected", "Rejected")
    ]
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='resident_profiles')
    society = models.ForeignKey(Society, on_delete=models.SET_NULL, null=True, blank=True, related_name='residents')
    block = models.ForeignKey(BlockTower, on_delete=models.SET_NULL, null=True, blank=True, related_name='residents')
    flat = models.ForeignKey(Flat, on_delete=models.SET_NULL, null=True, blank=True, related_name='residents')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="Pending")
    approved_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='approved_residents')
    approved_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.user.email} - {self.society.name if self.society else 'No Society'}"

    