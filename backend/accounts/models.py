from django.db import models
from django.contrib.auth.models import AbstractUser


class CustomUser(AbstractUser):
    ROLE_CHOICES = [
        ("ADMIN", "Admin"),
        ("RESIDENT", "Resident"),
        ("SECURITY", "Security"),
        ("STAFF", "Staff"),
    ]

    full_name = models.CharField(max_length=255)
    email = models.EmailField(unique=True)
    phone_number = models.CharField(max_length=20, blank=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default="RESIDENT")

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["username", "full_name"]

    def __str__(self):
        return f"{self.full_name} ({self.email})"


# Alias for convenience used throughout the codebase
User = CustomUser


class ResidentProfile(models.Model):
    STATUS_CHOICES = [
        ("Pending", "Pending"),
        ("Approved", "Approved"),
        ("Rejected", "Rejected"),
    ]

    user = models.OneToOneField(
        CustomUser,
        on_delete=models.CASCADE,
        related_name="resident_profile"
    )
    society = models.ForeignKey(
        "society.Society",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="residents"
    )
    block = models.ForeignKey(
        "society.BlockTower",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="residents"
    )
    flat = models.ForeignKey(
        "society.Flat",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="residents"
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="Pending")
    approved_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="approved_residents"
    )
    approved_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.full_name} - {self.status}"