from django.db import models
from django.conf import settings

class Relationship(models.Model):
    name = models.CharField(max_length=50, unique=True)

    def __str__(self):
        return self.name

class VerificationStatus(models.Model):
    STATUS_CHOICES = [
        ('Pending', 'Pending'),
        ('Verified', 'Verified'),
        ('Rejected', 'Rejected'),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Pending')
    notes = models.TextField(blank=True, null=True)

    def __str__(self):
        return self.status

class Guardian(models.Model):
    resident = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='guardians')
    name = models.CharField(max_length=255)
    phone = models.CharField(max_length=20)
    relationship = models.ForeignKey(Relationship, on_delete=models.SET_NULL, null=True)
    is_primary = models.BooleanField(default=False)
    verified = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.name} ({self.relationship.name if self.relationship else 'Guardian'})"

class EmergencyContact(models.Model):
    resident = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='emergency_contacts')
    name = models.CharField(max_length=255)
    phone = models.CharField(max_length=20)
    email = models.EmailField(blank=True, null=True)
    relationship = models.ForeignKey(Relationship, on_delete=models.SET_NULL, null=True)
    is_primary = models.BooleanField(default=False)
    verified = models.BooleanField(default=False)
    verification_status = models.ForeignKey(VerificationStatus, on_delete=models.SET_NULL, null=True, blank=True)
    
    # OTP fields for contact verification
    otp = models.CharField(max_length=6, blank=True, null=True)
    otp_created_at = models.DateTimeField(blank=True, null=True)
    otp_expires_at = models.DateTimeField(blank=True, null=True)
    verified_at = models.DateTimeField(blank=True, null=True)

    def __str__(self):
        return f"{self.name} - {self.phone}"


class ResidentGuardian(models.Model):
    STATUS_CHOICES = [
        ('Pending', 'Pending'),
        ('Active', 'Active'),
        ('Rejected', 'Rejected'),
    ]

    resident = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='linked_guardians'
    )
    guardian = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='linked_residents'
    )
    relationship = models.ForeignKey(Relationship, on_delete=models.SET_NULL, null=True, blank=True)
    relationship_name = models.CharField(max_length=50, blank=True, null=True)
    is_primary = models.BooleanField(default=False)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Pending')
    linked_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('resident', 'guardian')
        verbose_name = 'Resident Guardian'
        verbose_name_plural = 'Resident Guardians'

    def __str__(self):
        rel = self.relationship.name if self.relationship else (self.relationship_name or 'Guardian')
        return f"{self.resident.full_name} -> {self.guardian.full_name} ({rel}, {self.status})"



