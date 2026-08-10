"""
sos/tasks.py

Celery task definitions for SOS auto-escalation and notifications background processing.
"""

import logging
from celery import shared_task

logger = logging.getLogger(__name__)


@shared_task(name="sos.tasks.process_auto_escalation")
def process_auto_escalation():
    """
    Periodic Celery task triggered by Celery Beat to process pending SOS escalations.
    Replaces the previous in-process daemon thread.
    """
    from .services import SOSService
    try:
        SOSService.process_pending_escalations()
        return "Successfully checked and processed pending escalations."
    except Exception as e:
        logger.error(f"[CELERY TASK ERROR] process_auto_escalation failed: {e}")
        raise e


@shared_task(name="sos.tasks.trigger_incident_escalation")
def trigger_incident_escalation(incident_id):
    """
    Asynchronous Celery task triggered when a specific incident is created or rejected.
    """
    from .services import SOSService
    from .models import SOSIncident
    try:
        incident = SOSIncident.objects.filter(id=incident_id).first()
        if incident:
            SOSService.process_pending_escalations()
            return f"Processed auto-escalation for incident #{incident_id}."
        return f"Incident #{incident_id} not found."
    except Exception as e:
        logger.error(f"[CELERY TASK ERROR] trigger_incident_escalation failed for incident #{incident_id}: {e}")
        raise e


@shared_task(name="sos.tasks.send_guardian_notifications")
def send_guardian_notifications(incident_id):
    """
    Asynchronous Celery task to dispatch emergency notifications to guardians.
    """
    from .services import SOSService
    from .models import SOSIncident
    try:
        incident = SOSIncident.objects.filter(id=incident_id).first()
        if incident:
            SOSService._notify_primary_guardians(incident)
            return f"Guardian notifications dispatched for incident #{incident_id}."
        return f"Incident #{incident_id} not found."
    except Exception as e:
        logger.error(f"[CELERY TASK ERROR] send_guardian_notifications failed for incident #{incident_id}: {e}")
        raise e


@shared_task(name="sos.tasks.retry_failed_notifications")
def retry_failed_notifications():
    """
    Periodic Celery task to audit and log/retry failed notifications.
    """
    from notifications.models import NotificationLog
    try:
        failed_logs = NotificationLog.objects.filter(status='FAILURE').order_by('-created_at')[:50]
        failed_count = failed_logs.count()
        logger.info(f"[CELERY AUDIT] Audited failed notifications: {failed_count} failures found.")
        return f"Audited failed notifications. {failed_count} entries recorded."
    except Exception as e:
        logger.error(f"[CELERY TASK ERROR] retry_failed_notifications failed: {e}")
        raise e
