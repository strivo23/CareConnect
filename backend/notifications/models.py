from django.db import models
from django.conf import settings

class Notification(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, null=True, blank=True, related_name='notifications')
    title = models.CharField(max_length=255)
    message = models.TextField()
    category = models.CharField(max_length=50, default='general')
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    priority = models.CharField(max_length=20, default='LOW')
    location = models.CharField(max_length=255, null=True, blank=True)
    incident = models.ForeignKey(
        'sos.SOSIncident',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='notifications'
    )

    def __str__(self):
        return self.title


class FCMDevice(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='fcm_devices')
    token = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.email} - {self.token[:20]}..."


class NotificationTemplate(models.Model):
    name = models.CharField(max_length=100, unique=True)
    title_template = models.CharField(max_length=255)
    message_template = models.TextField()
    category = models.CharField(max_length=50, default='general')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


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

