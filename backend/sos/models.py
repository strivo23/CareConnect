from django.db import models
from django.conf import settings


class EmergencyCategory(models.Model):
    name = models.CharField(max_length=100, unique=True)
    icon = models.CharField(max_length=100, blank=True)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name

    class Meta:
        verbose_name = "Emergency Category"
        verbose_name_plural = "Emergency Categories"
        ordering = ["name"]


class SOSIncident(models.Model):
    STATUS_CHOICES = [
        ("Pending", "Pending"),
        ("Accepted", "Accepted"),
        ("In Progress", "In Progress"),
        ("Resolved", "Resolved"),
        ("Cancelled", "Cancelled"),
    ]

    resident = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="sos_incidents"
    )

    category = models.ForeignKey(
        EmergencyCategory,
        on_delete=models.CASCADE,
        related_name="incidents"
    )

    message = models.TextField(blank=True)

    latitude = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        null=True,
        blank=True
    )

    longitude = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        null=True,
        blank=True
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default="Pending"
    )

    address = models.TextField(blank=True)

    priority = models.CharField(
        max_length=20,
        choices=[
            ("LOW", "LOW"),
            ("MEDIUM", "MEDIUM"),
            ("HIGH", "HIGH"),
            ("CRITICAL", "CRITICAL"),
        ],
        default="HIGH"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.resident.full_name} - {self.category.name} ({self.status})"

    class Meta:
        verbose_name = "SOS Incident"
        verbose_name_plural = "SOS Incidents"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status"]),
            models.Index(fields=["resident"]),
            models.Index(fields=["created_at"]),
        ]


class SOSEmergencyMessage(models.Model):
    incident = models.ForeignKey(
        SOSIncident,
        on_delete=models.CASCADE,
        related_name="messages"
    )
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="sos_messages"
    )
    message = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Message by {self.sender.email} on Incident #{self.incident.id}"

    class Meta:
        verbose_name = "SOS Emergency Message"
        verbose_name_plural = "SOS Emergency Messages"
        ordering = ["created_at"]