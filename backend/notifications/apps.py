from django.apps import AppConfig
from django.db.models.signals import post_migrate

def seed_default_notification_templates(sender, **kwargs):
    try:
        from .models import NotificationTemplate
        default_templates = [
            {
                "name": "SOS_CREATED",
                "category": "sos",
                "title_template": "🚨 Emergency SOS Alert from {resident_name}",
                "message_template": "Emergency SOS triggered by {resident_name} ({emergency_type}) at {location} at {time}. Message: {message}",
                "subject_template": "🚨 CareConnect SOS Alert: {resident_name}",
                "email_template": "An emergency SOS alert was triggered on CareConnect.\nResident: {resident_name}\nCategory: {emergency_type}\nLocation: {location}\nTime: {time}",
                "push_template": "{resident_name} triggered an SOS emergency alert!",
                "sms_template": "EMERGENCY SOS: {resident_name} requested assistance at {location}. Message: {message}"
            },
            {
                "name": "GUARDIAN_REQUEST",
                "category": "guardian",
                "title_template": "🤝 Guardian Connection Request from {resident_name}",
                "message_template": "{resident_name} has invited you to become a primary emergency guardian on CareConnect.",
                "subject_template": "Guardian Request from {resident_name}",
                "email_template": "{resident_name} has requested you as their emergency guardian on CareConnect.",
                "push_template": "{resident_name} sent you a guardian request.",
                "sms_template": "CareConnect: {resident_name} requested you as an emergency guardian."
            },
            {
                "name": "GUARDIAN_ACCEPTED",
                "category": "guardian",
                "title_template": "✅ Guardian Request Accepted",
                "message_template": "{guardian_name} has accepted your emergency guardian request.",
                "subject_template": "Guardian Connection Accepted",
                "email_template": "{guardian_name} is now registered as your active emergency guardian.",
                "push_template": "{guardian_name} accepted your guardian request.",
                "sms_template": "CareConnect: {guardian_name} accepted your guardian request."
            },
            {
                "name": "GUARDIAN_REJECTED",
                "category": "guardian",
                "title_template": "❌ Guardian Request Declined",
                "message_template": "{guardian_name} has declined the guardian request.",
                "subject_template": "Guardian Request Status Update",
                "email_template": "{guardian_name} has declined the guardian connection request.",
                "push_template": "{guardian_name} declined guardian request.",
                "sms_template": "CareConnect: Guardian request was declined by {guardian_name}."
            },
            {
                "name": "VOLUNTEER_ASSIGNED",
                "category": "sos",
                "title_template": "🤝 Volunteer Assigned to SOS #{incident_id}",
                "message_template": "Volunteer {volunteer_name} has responded to SOS #{incident_id} and is on the way.",
                "subject_template": "Volunteer Responded to SOS #{incident_id}",
                "email_template": "Volunteer {volunteer_name} has accepted SOS #{incident_id}.",
                "push_template": "Volunteer {volunteer_name} assigned to SOS #{incident_id}.",
                "sms_template": "CareConnect: Volunteer {volunteer_name} assigned to SOS #{incident_id}."
            },
            {
                "name": "SECURITY_ASSIGNED",
                "category": "sos",
                "title_template": "🛡️ Security Assigned to SOS #{incident_id}",
                "message_template": "Security Guard {security_name} has been dispatched to SOS #{incident_id}.",
                "subject_template": "Security Dispatched for SOS #{incident_id}",
                "email_template": "Security officer {security_name} is coordinating response for SOS #{incident_id}.",
                "push_template": "Security {security_name} assigned to SOS #{incident_id}.",
                "sms_template": "CareConnect: Security {security_name} dispatched for SOS #{incident_id}."
            },
            {
                "name": "INCIDENT_ESCALATED",
                "category": "sos",
                "title_template": "⚠️ SOS Incident Escalated: #{incident_id}",
                "message_template": "SOS incident #{incident_id} ({emergency_type}) for {resident_name} has been ESCALATED to Security & Admin.",
                "subject_template": "⚠️ ESCALATION: SOS #{incident_id}",
                "email_template": "SOS incident #{incident_id} was escalated due to non-response.",
                "push_template": "ESCALATION ALERT: SOS #{incident_id} escalated!",
                "sms_template": "URGENT: SOS #{incident_id} for {resident_name} has been ESCALATED."
            },
            {
                "name": "INCIDENT_RESOLVED",
                "category": "sos",
                "title_template": "✅ SOS Incident Resolved: #{incident_id}",
                "message_template": "SOS incident #{incident_id} has been marked as RESOLVED.",
                "subject_template": "SOS Incident #{incident_id} Resolved",
                "email_template": "SOS incident #{incident_id} for {resident_name} has been successfully resolved.",
                "push_template": "SOS #{incident_id} marked as resolved.",
                "sms_template": "CareConnect: SOS #{incident_id} has been resolved."
            },
            {
                "name": "INCIDENT_CLOSED",
                "category": "sos",
                "title_template": "🔒 SOS Incident Closed: #{incident_id}",
                "message_template": "SOS incident #{incident_id} has been closed.",
                "subject_template": "SOS Incident #{incident_id} Closed",
                "email_template": "SOS incident #{incident_id} has been officially closed.",
                "push_template": "SOS #{incident_id} is now closed.",
                "sms_template": "CareConnect: SOS #{incident_id} closed."
            }
        ]

        for tpl in default_templates:
            NotificationTemplate.objects.get_or_create(
                name=tpl["name"],
                defaults=tpl
            )
    except Exception:
        pass


class NotificationsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "notifications"

    def ready(self):
        post_migrate.connect(seed_default_notification_templates, sender=self)
