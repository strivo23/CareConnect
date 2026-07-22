from django.db import models
from django.contrib.auth.models import AbstractUser


class CustomUser(AbstractUser):
    ROLE_CHOICES = [
        ("ADMIN", "Admin"),
        ("RESIDENT", "Resident"),
        ("SECURITY", "Security"),
        ("STAFF", "Staff"),
        ("VOLUNTEER", "Volunteer"),
        ("GUARDIAN", "Guardian"),
    ]

    full_name = models.CharField(max_length=255)
    email = models.EmailField(unique=True)
    phone_number = models.CharField(max_length=20, blank=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default="RESIDENT")
    is_verified = models.BooleanField(default=False)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["username", "full_name"]

    def __str__(self):
        return f"{self.full_name} ({self.email})"


# Alias for convenience used throughout the codebase
User = CustomUser


class OTPVerification(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='otps')
    otp = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_verified = models.BooleanField(default=False)

    def __str__(self):
        return f"OTP {self.otp} for {self.user.email}"


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


class VolunteerProfile(models.Model):
    user = models.OneToOneField(
        CustomUser,
        on_delete=models.CASCADE,
        related_name="volunteer_profile"
    )
    skills = models.TextField(blank=True)
    availability = models.CharField(max_length=255, blank=True)
    service_area = models.CharField(max_length=255, blank=True)
    
    is_online = models.BooleanField(default=True)
    latitude = models.DecimalField(max_digits=15, decimal_places=10, null=True, blank=True)
    longitude = models.DecimalField(max_digits=15, decimal_places=10, null=True, blank=True)

    visibility_radius = models.FloatField(default=5000.0)  # in meters

    def __str__(self):
        return f"Volunteer Profile: {self.user.full_name}"


class SecurityProfile(models.Model):
    user = models.OneToOneField(
        CustomUser,
        on_delete=models.CASCADE,
        related_name="security_profile"
    )
    shift = models.CharField(max_length=100, blank=True)
    employee_id = models.CharField(max_length=100, blank=True)
    assigned_society = models.ForeignKey(
        "society.Society",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="security_staff"
    )

    def __str__(self):
        return f"Security Profile: {self.user.full_name} ({self.employee_id})"


class GuardianProfile(models.Model):
    user = models.OneToOneField(
        CustomUser,
        on_delete=models.CASCADE,
        related_name="guardian_profile"
    )
    guardian_code = models.CharField(max_length=20, unique=True, null=True, blank=True, db_index=True)
    relationship = models.ForeignKey(
        "emergency.Relationship",
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )
    phone_number = models.CharField(max_length=20, blank=True)
    email = models.EmailField(blank=True)

    def save(self, *args, **kwargs):
        if not self.guardian_code:
            self.guardian_code = self.generate_code()
        super().save(*args, **kwargs)

    @classmethod
    def generate_code(cls):
        import secrets, string
        while True:
            code = "CC-GD-" + "".join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(6))
            if not cls.objects.filter(guardian_code=code).exists():
                return code

    def __str__(self):
        return f"Guardian Profile: {self.user.full_name} ({self.guardian_code})"