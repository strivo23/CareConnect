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
        import os
        from django.conf import settings
        # Start daemon only in the main process (skip reloader helper in dev)
        if os.environ.get('RUN_MAIN') == 'true' or not settings.DEBUG:
            from .services import SOSService
            SOSService.start_escalation_daemon()

