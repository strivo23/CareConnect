from django.db import models
from django.contrib.auth.models import AbstractUser
from django.conf import settings


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


class PasswordResetOTP(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='password_reset_otps')
    email = models.EmailField()
    otp_hash = models.CharField(max_length=128)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    attempts = models.IntegerField(default=0)
    verified = models.BooleanField(default=False)
    used = models.BooleanField(default=False)
    reset_token = models.CharField(max_length=128, unique=True, null=True, blank=True)
    reset_token_expires_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-id']

    def __str__(self):
        return f"Password Reset OTP for {self.email} (verified={self.verified}, used={self.used})"



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
    verification_date = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="verified_residents"
    )
    remarks = models.TextField(blank=True, null=True)
    aadhaar_card = models.FileField(upload_to="documents/aadhaar/", null=True, blank=True)
    driving_license = models.FileField(upload_to="documents/dl/", null=True, blank=True)
    society_id_card = models.FileField(upload_to="documents/society_id/", null=True, blank=True)
    profile_photo = models.FileField(upload_to="profile_photos/", null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.full_name} - {self.status}"


class VolunteerProfile(models.Model):
    STATUS_CHOICES = [
        ("Pending", "Pending"),
        ("Approved", "Approved"),
        ("Rejected", "Rejected"),
        ("Suspended", "Suspended"),
    ]

    user = models.OneToOneField(
        CustomUser,
        on_delete=models.CASCADE,
        related_name="volunteer_profile"
    )
    skills = models.TextField(blank=True)
    availability = models.CharField(max_length=255, blank=True)
    service_area = models.CharField(max_length=255, blank=True)
    emergency_training = models.CharField(max_length=255, blank=True, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="Pending")

    assigned_society = models.ForeignKey(
        "society.Society",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assigned_volunteers"
    )
    assigned_block = models.ForeignKey(
        "society.BlockTower",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assigned_volunteers"
    )

    AVAILABILITY_STATUS_CHOICES = [
        ("ONLINE", "Online"),
        ("OFFLINE", "Offline"),
        ("BUSY", "Busy"),
        ("UNAVAILABLE", "Unavailable"),
    ]

    is_online = models.BooleanField(default=True)
    availability_status = models.CharField(max_length=20, choices=AVAILABILITY_STATUS_CHOICES, default="ONLINE")
    latitude = models.DecimalField(max_digits=15, decimal_places=10, null=True, blank=True)
    longitude = models.DecimalField(max_digits=15, decimal_places=10, null=True, blank=True)
    visibility_radius = models.FloatField(default=5000.0)
    last_updated = models.DateTimeField(auto_now=True, null=True, blank=True)

    profile_photo = models.FileField(upload_to="profile_photos/", null=True, blank=True)
    id_proof = models.FileField(upload_to="documents/volunteer_id/", null=True, blank=True)
    verification_date = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="verified_volunteers"
    )
    remarks = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)

    def __str__(self):
        return f"Volunteer Profile: {self.user.full_name} ({self.status} / {self.availability_status})"


class SecurityProfile(models.Model):
    VERIFICATION_CHOICES = [
        ("Pending", "Pending"),
        ("Approved", "Approved"),
        ("Rejected", "Rejected"),
    ]
    EMPLOYMENT_CHOICES = [
        ("Active", "Active"),
        ("Inactive", "Inactive"),
        ("Suspended", "Suspended"),
    ]
    DUTY_STATUS_CHOICES = [
        ("AVAILABLE", "Available"),
        ("ON_DUTY", "On Duty"),
        ("BUSY", "Busy"),
        ("RESPONDING", "Responding"),
        ("OFFLINE", "Offline"),
    ]

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
    assigned_block = models.ForeignKey(
        "society.BlockTower",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="security_staff"
    )
    verification_status = models.CharField(max_length=20, choices=VERIFICATION_CHOICES, default="Pending")
    employment_status = models.CharField(max_length=20, choices=EMPLOYMENT_CHOICES, default="Active")

    is_on_duty = models.BooleanField(default=True)
    duty_status = models.CharField(max_length=20, choices=DUTY_STATUS_CHOICES, default="AVAILABLE")
    latitude = models.DecimalField(max_digits=15, decimal_places=10, null=True, blank=True)
    longitude = models.DecimalField(max_digits=15, decimal_places=10, null=True, blank=True)
    current_incident = models.ForeignKey(
        "sos.SOSIncident",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assigned_security_profiles"
    )
    last_updated = models.DateTimeField(auto_now=True, null=True, blank=True)

    profile_photo = models.FileField(upload_to="profile_photos/", null=True, blank=True)
    id_proof = models.FileField(upload_to="documents/security_id/", null=True, blank=True)
    verification_date = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="verified_security"
    )
    remarks = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)

    def __str__(self):
        return f"Security Profile: {self.user.full_name} ({self.employee_id} / {self.duty_status})"


class GuardianProfile(models.Model):
    VERIFICATION_CHOICES = [
        ("Pending", "Pending"),
        ("Approved", "Approved"),
        ("Rejected", "Rejected"),
    ]

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
    verification_status = models.CharField(max_length=20, choices=VERIFICATION_CHOICES, default="Pending")
    id_proof = models.FileField(upload_to="documents/guardian_id/", null=True, blank=True)
    verification_date = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="verified_guardians"
    )
    remarks = models.TextField(blank=True, null=True)

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


class UserDocument(models.Model):
    DOCUMENT_TYPES = [
        ("Aadhaar", "Aadhaar Card"),
        ("Driving License", "Driving License"),
        ("Employee ID", "Employee ID"),
        ("Society ID", "Society ID"),
        ("Profile Photo", "Profile Photo"),
    ]
    STATUS_CHOICES = [
        ("Pending", "Pending"),
        ("Approved", "Approved"),
        ("Rejected", "Rejected"),
    ]

    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name="documents")
    document_type = models.CharField(max_length=50, choices=DOCUMENT_TYPES)
    file = models.FileField(upload_to="documents/user_docs/")
    title = models.CharField(max_length=150, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="Pending")
    remarks = models.TextField(blank=True, null=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.full_name} - {self.document_type} ({self.status})"

    class Meta:
        ordering = ["-uploaded_at"]


class UserDirectoryProfile(models.Model):
    VISIBILITY_CHOICES = [
        ('PUBLIC', 'Public (Society Wide)'),
        ('RESPONDERS', 'Responders Only'),
        ('GUARDIANS_ONLY', 'Linked Guardians Only'),
        ('PRIVATE', 'Private (Admin Only)'),
    ]

    CONTACT_METHODS = [
        ('PHONE', 'Phone'),
        ('EMAIL', 'Email'),
        ('APP_CHAT', 'App Chat'),
    ]

    user = models.OneToOneField(
        CustomUser,
        on_delete=models.CASCADE,
        related_name="directory_profile"
    )
    visibility = models.CharField(max_length=20, choices=VISIBILITY_CHOICES, default='PUBLIC')
    is_available = models.BooleanField(default=True)
    is_emergency_contact = models.BooleanField(default=False)
    preferred_contact_method = models.CharField(max_length=20, choices=CONTACT_METHODS, default='PHONE')
    bio = models.CharField(max_length=255, blank=True, null=True)
    last_active = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "User Directory Profile"
        verbose_name_plural = "User Directory Profiles"

    def __str__(self):
        return f"Directory Profile: {self.user.full_name} ({self.visibility})"