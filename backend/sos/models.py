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
    emergency_description = models.TextField(blank=True)
    voice_message = models.FileField(upload_to="voice_messages/", null=True, blank=True)

    latitude = models.DecimalField(
        max_digits=15,
        decimal_places=10,
        null=True,
        blank=True
    )


    longitude = models.DecimalField(
        max_digits=15,
        decimal_places=10,
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


class EscalationConfig(models.Model):
    response_time_minutes = models.IntegerField(default=5)
    escalation_enabled = models.BooleanField(default=True)
    notify_security = models.BooleanField(default=True)
    notify_volunteers = models.BooleanField(default=True)
    notify_admin = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True, null=True, blank=True)
    
    # Backward compatibility properties/fields
    response_time_window = models.IntegerField(default=30)  # window in seconds for rapid testing/backwards compatibility
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"Escalation Config: {self.response_time_minutes}m ({self.response_time_window}s window)"

EscalationConfiguration = EscalationConfig  # Alias for requirement compatibility


class EscalationLog(models.Model):
    incident = models.ForeignKey(
        SOSIncident,
        on_delete=models.CASCADE,
        related_name="escalations"
    )
    step = models.CharField(max_length=50)  # 'Primary Guardian', 'Secondary Guardian', 'Emergency Contacts', 'Security', 'Volunteers', 'Admin'
    escalation_level = models.CharField(max_length=50, blank=True, null=True)
    previous_recipient = models.CharField(max_length=255, blank=True, null=True)
    new_recipient = models.CharField(max_length=255, blank=True, null=True)
    reason = models.TextField(blank=True, null=True)
    status = models.CharField(max_length=20, default='PENDING')  # 'PENDING', 'TRIGGERED', 'ACCEPTED', 'CANCELLED', 'REJECTED'
    response_status = models.CharField(max_length=50, blank=True, null=True)
    scheduled_at = models.DateTimeField()
    triggered_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Incident #{self.incident.id} - {self.step} ({self.status})"

    class Meta:
        ordering = ["scheduled_at"]