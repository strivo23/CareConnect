from django.db import models
from django.conf import settings

class Notification(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, null=True, blank=True, related_name='notifications')
    title = models.CharField(max_length=255)
    message = models.TextField()
    category = models.CharField(max_length=50, default='general')
    is_read = models.BooleanField(default=False)
    read_time = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    priority = models.CharField(max_length=20, default='LOW')
    delivery_status = models.CharField(max_length=20, default='SENT')
    delivery_channel = models.CharField(max_length=20, default='IN_APP')
    recipient_role = models.CharField(max_length=30, blank=True, null=True)
    notification_type = models.CharField(max_length=50, default='SOS_CREATED')

    location = models.CharField(max_length=255, null=True, blank=True)
    incident = models.ForeignKey(
        'sos.SOSIncident',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='notifications'
    )

    def __str__(self):
        return f"{self.title} -> {self.user.email if self.user else 'All'}"

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user']),
            models.Index(fields=['created_at']),
            models.Index(fields=['is_read']),
            models.Index(fields=['priority']),
        ]



class FCMDevice(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='fcm_devices')
    token = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.email} - {self.token[:20]}..."


class NotificationTemplate(models.Model):
    name = models.CharField(max_length=100, unique=True)
    category = models.CharField(max_length=50, default='general')
    title_template = models.CharField(max_length=255, blank=True)
    message_template = models.TextField(blank=True)
    subject_template = models.CharField(max_length=255, blank=True)
    email_template = models.TextField(blank=True)
    push_template = models.TextField(blank=True)
    sms_template = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.name} Template"


class NotificationLog(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)
    channel = models.CharField(max_length=50)  # 'FCM', 'EMAIL', 'SMS', 'IN_APP'
    status = models.CharField(max_length=50, default='SUCCESS')  # 'SUCCESS', 'FAILURE'
    recipient = models.CharField(max_length=255)
    title = models.CharField(max_length=255, blank=True)
    message = models.TextField()
    error_message = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.channel} log to {self.recipient} ({self.status})"


class SMSLog(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='sms_logs')
    to_number = models.CharField(max_length=30)
    message = models.TextField()
    provider = models.CharField(max_length=50, default='CONSOLE')  # 'CONSOLE', 'TWILIO'
    status = models.CharField(max_length=20, default='SENT')       # 'SENT', 'FAILED'
    error_message = models.TextField(blank=True, null=True)
    sent_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"SMS to {self.to_number} [{self.status}] ({self.provider})"


