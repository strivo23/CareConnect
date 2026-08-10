"""
sos/apps.py

App configuration for the SOS module.
"""

from django.apps import AppConfig


class SosConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "sos"
    verbose_name = "SOS & Emergency"

    def ready(self):
        # Background tasks and auto-escalation are processed via Celery workers and Celery Beat.
        pass
