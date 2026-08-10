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
        ("Assigned", "Assigned"),
        ("In Progress", "In Progress"),
        ("Resolved", "Resolved"),
        ("Cancelled", "Cancelled"),
        ("OPEN", "OPEN"),
        ("ACTIVE", "ACTIVE"),
        ("ESCALATED", "ESCALATED"),
        ("RESOLVED", "RESOLVED"),
        ("CLOSED", "CLOSED"),
    ]

    LIFECYCLE_CHOICES = [
        ("OPEN", "OPEN"),
        ("ACTIVE", "ACTIVE"),
        ("ESCALATED", "ESCALATED"),
        ("RESOLVED", "RESOLVED"),
        ("CLOSED", "CLOSED"),
    ]

    ASSIGNMENT_STATUS_CHOICES = [
        ("Pending", "Pending"),
        ("Assigned", "Assigned"),
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
    voice_duration = models.IntegerField(null=True, blank=True, help_text="Duration in seconds")
    voice_uploaded_at = models.DateTimeField(null=True, blank=True)

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
        default="Pending",
        db_index=True
    )

    current_status = models.CharField(
        max_length=20,
        choices=LIFECYCLE_CHOICES,
        default="OPEN",
        db_index=True
    )

    assigned_responder = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assigned_incidents"
    )
    assigned_role = models.CharField(max_length=50, null=True, blank=True)
    accepted_at = models.DateTimeField(null=True, blank=True)
    assignment_status = models.CharField(
        max_length=20,
        choices=ASSIGNMENT_STATUS_CHOICES,
        default="Pending"
    )

    address = models.TextField(blank=True)
    city = models.CharField(max_length=100, blank=True, null=True)
    state = models.CharField(max_length=100, blank=True, null=True)
    country = models.CharField(max_length=100, blank=True, null=True)
    pincode = models.CharField(max_length=20, blank=True, null=True)

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

    # Day 15 Lifecycle & Closure Tracking Fields
    opened_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    active_at = models.DateTimeField(null=True, blank=True)
    escalated_at = models.DateTimeField(null=True, blank=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    closed_at = models.DateTimeField(null=True, blank=True)

    resolution_summary = models.TextField(null=True, blank=True)
    closure_reason = models.CharField(max_length=255, null=True, blank=True)
    closure_notes = models.TextField(null=True, blank=True)

    resolved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="resolved_incidents",
        db_index=True
    )
    closed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="closed_incidents",
        db_index=True
    )
    last_status_changed_at = models.DateTimeField(auto_now=True, null=True, blank=True, db_index=True)

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
    secondary_guardian_delay = models.IntegerField(default=60, help_text="Delay in seconds before secondary guardian escalation")
    security_delay = models.IntegerField(default=120, help_text="Delay in seconds before security staff escalation")
    volunteer_delay = models.IntegerField(default=180, help_text="Delay in seconds before community volunteer escalation")
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
    duration = models.IntegerField(default=0, help_text="Elapsed time in seconds before escalation")
    triggered_by = models.CharField(max_length=100, default='SYSTEM')
    scheduled_at = models.DateTimeField()
    triggered_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Incident #{self.incident.id} - {self.step} ({self.status})"

    class Meta:
        ordering = ["scheduled_at"]


class AssignmentLog(models.Model):
    incident = models.ForeignKey(
        SOSIncident,
        on_delete=models.CASCADE,
        related_name="assignment_logs"
    )
    responder = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assignment_audits"
    )
    role = models.CharField(max_length=50)
    accepted_at = models.DateTimeField()
    previous_status = models.CharField(max_length=50)
    new_status = models.CharField(max_length=50)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        responder_name = self.responder.full_name if self.responder else "Unknown"
        return f"AssignmentLog: Incident #{self.incident.id} assigned to {responder_name} ({self.role})"

    class Meta:
        verbose_name = "Assignment Log"
        verbose_name_plural = "Assignment Logs"
        ordering = ["-created_at"]


class IncidentStatusLog(models.Model):
    incident = models.ForeignKey(
        SOSIncident,
        on_delete=models.CASCADE,
        related_name="status_logs"
    )
    old_status = models.CharField(max_length=50)
    new_status = models.CharField(max_length=50)
    changed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="incident_status_changes"
    )
    role = models.CharField(max_length=50, null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)
    remarks = models.TextField(blank=True, null=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)

    class Meta:
        verbose_name = "Incident Status Log"
        verbose_name_plural = "Incident Status Logs"
        ordering = ["-timestamp"]

    def __str__(self):
        changed_by_name = self.changed_by.full_name if self.changed_by else "System"
        return f"Incident #{self.incident_id}: {self.old_status} -> {self.new_status} by {changed_by_name}"


class IncidentChatMessage(models.Model):
    MESSAGE_TYPES = [
        ('TEXT', 'TEXT'),
        ('SYSTEM', 'SYSTEM'),
        ('IMAGE', 'IMAGE'),
        ('LOCATION', 'LOCATION'),
        ('VOICE', 'VOICE'),
        ('FILE', 'FILE'),
    ]

    ROLE_CHOICES = [
        ('RESIDENT', 'RESIDENT'),
        ('GUARDIAN', 'GUARDIAN'),
        ('VOLUNTEER', 'VOLUNTEER'),
        ('SECURITY', 'SECURITY'),
        ('ADMIN', 'ADMIN'),
        ('SYSTEM', 'SYSTEM'),
    ]

    incident = models.ForeignKey(
        SOSIncident,
        on_delete=models.CASCADE,
        related_name="chat_messages"
    )
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="sent_chat_messages"
    )
    sender_role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='SYSTEM')
    message = models.TextField(blank=True, default='')
    message_type = models.CharField(max_length=20, choices=MESSAGE_TYPES, default='TEXT')
    attachment = models.FileField(upload_to='chat_attachments/%Y/%m/%d/', blank=True, null=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    is_read = models.BooleanField(default=False)
    is_deleted = models.BooleanField(default=False)
    reply_to = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="replies"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Incident Chat Message"
        verbose_name_plural = "Incident Chat Messages"
        ordering = ["created_at"]
        indexes = [
            models.Index(fields=["incident", "created_at"]),
            models.Index(fields=["sender"]),
            models.Index(fields=["message_type"]),
        ]

    def __str__(self):
        sender_label = self.sender.full_name if self.sender else "SYSTEM"
        return f"Chat #{self.id} on Incident #{self.incident_id} by {sender_label} ({self.message_type})"


class IncidentResponseUpdate(models.Model):
    UPDATE_TYPES = [
        ('TEXT', 'TEXT'),
        ('STATUS', 'STATUS'),
        ('ARRIVAL', 'ARRIVAL'),
        ('MEDICAL', 'MEDICAL'),
        ('SECURITY', 'SECURITY'),
        ('NOTE', 'NOTE'),
        ('SYSTEM', 'SYSTEM'),
    ]

    ROLE_CHOICES = [
        ('RESIDENT', 'RESIDENT'),
        ('GUARDIAN', 'GUARDIAN'),
        ('VOLUNTEER', 'VOLUNTEER'),
        ('SECURITY', 'SECURITY'),
        ('ADMIN', 'ADMIN'),
        ('SYSTEM', 'SYSTEM'),
    ]

    VISIBILITY_CHOICES = [
        ('PUBLIC', 'PUBLIC'),
        ('RESPONDERS', 'RESPONDERS'),
        ('GUARDIANS', 'GUARDIANS'),
        ('INTERNAL', 'INTERNAL'),
    ]

    incident = models.ForeignKey(
        SOSIncident,
        on_delete=models.CASCADE,
        related_name="response_updates"
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="incident_updates"
    )
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='SYSTEM')
    update_type = models.CharField(max_length=20, choices=UPDATE_TYPES, default='TEXT')
    message = models.TextField()
    visibility = models.CharField(max_length=20, choices=VISIBILITY_CHOICES, default='PUBLIC')
    attachment = models.FileField(upload_to='response_updates/%Y/%m/%d/', blank=True, null=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Incident Response Update"
        verbose_name_plural = "Incident Response Updates"
        ordering = ["created_at"]
        indexes = [
            models.Index(fields=["incident", "created_at"]),
            models.Index(fields=["author"]),
            models.Index(fields=["role"]),
            models.Index(fields=["visibility"]),
        ]

    def __str__(self):
        author_label = self.author.full_name if self.author else "SYSTEM"
        return f"Update #{self.id} on Incident #{self.incident_id} by {author_label} ({self.update_type})"


class SecurityIncidentResolutionReport(models.Model):
    incident = models.OneToOneField(
        SOSIncident,
        on_delete=models.CASCADE,
        related_name="security_resolution_report"
    )
    resolved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="submitted_security_resolutions"
    )
    resolution_summary = models.TextField()
    actions_taken = models.TextField(blank=True, default='')
    medical_assistance = models.BooleanField(default=False)
    police_assistance = models.BooleanField(default=False)
    fire_assistance = models.BooleanField(default=False)
    property_damage = models.BooleanField(default=False)
    casualties = models.IntegerField(default=0)
    additional_notes = models.TextField(blank=True, null=True)
    attachment = models.FileField(upload_to='resolutions/%Y/%m/%d/', blank=True, null=True)
    resolved_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Security Incident Resolution Report"
        verbose_name_plural = "Security Incident Resolution Reports"

    def __str__(self):
        return f"Resolution Report for Incident #{self.incident_id} by {self.resolved_by}"


class BroadcastLog(models.Model):
    TARGET_ROLE_CHOICES = [
        ('VOLUNTEER', 'Volunteer'),
        ('SECURITY', 'Security'),
        ('GUARDIAN', 'Guardian'),
        ('ADMIN', 'Admin'),
        ('ALL', 'All Responders'),
    ]

    STATUS_CHOICES = [
        ('SUCCESS', 'Success'),
        ('DELIVERED', 'Delivered'),
        ('FAILED', 'Failed'),
        ('NO_RESPONDERS_NEARBY', 'No Responders Nearby'),
        ('PARTIALLY_DELIVERED', 'Partially Delivered'),
    ]

    incident = models.ForeignKey(
        SOSIncident,
        on_delete=models.CASCADE,
        related_name="broadcast_logs"
    )
    target_role = models.CharField(max_length=20, choices=TARGET_ROLE_CHOICES, default='ALL')
    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="received_broadcasts"
    )
    recipient_name = models.CharField(max_length=255, blank=True, default='')
    distance_km = models.FloatField(null=True, blank=True)
    radius_km = models.FloatField(default=5.0)
    status = models.CharField(max_length=30, choices=STATUS_CHOICES, default='SUCCESS')
    delivery_channel = models.CharField(max_length=50, default='IN_APP')
    message = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Broadcast Log"
        verbose_name_plural = "Broadcast Logs"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["incident", "created_at"]),
            models.Index(fields=["target_role"]),
            models.Index(fields=["status"]),
        ]

    def __str__(self):
        return f"Broadcast #{self.id} for Incident #{self.incident_id} to {self.recipient_name or self.target_role} ({self.status})"



