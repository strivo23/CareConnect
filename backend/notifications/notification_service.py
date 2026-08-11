import logging
import os
from django.conf import settings
from django.core.mail import EmailMultiAlternatives, send_mail
from django.utils.html import strip_tags
from django.contrib.auth import get_user_model

from .models import Notification, FCMDevice, NotificationTemplate, NotificationLog, SMSLog

User = get_user_model()
logger = logging.getLogger(__name__)

# Firebase Admin SDK initialization
try:
    import firebase_admin
    from firebase_admin import credentials, messaging
except ImportError:
    firebase_admin = None
    credentials = None
    messaging = None

_firebase_initialized = False
if firebase_admin and not firebase_admin._apps:
    try:
        import json
        raw_json = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON', '').strip()
        if raw_json:
            service_account_info = json.loads(raw_json)
            cred = credentials.Certificate(service_account_info)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK initialized via environment JSON.")
        else:
            service_account_path = getattr(settings, 'FIREBASE_SERVICE_ACCOUNT_PATH', None)
            if service_account_path and os.path.exists(service_account_path):
                cred = credentials.Certificate(service_account_path)
                firebase_admin.initialize_app(cred)
                _firebase_initialized = True
                logger.info("Firebase Admin SDK initialized via certificate file.")
    except Exception as e:
        logger.warning(f"Firebase Admin SDK initialization skipped: {e}")


def _safe_str(s: str) -> str:
    if not s:
        return ""
    return s.replace('🚨', '[ALERT]').encode('ascii', 'ignore').decode('ascii')


# ---------------------------------------------------------------------------
# SMS Service Architecture (Pluggable for TextBee / Twilio / Console)
# ---------------------------------------------------------------------------

import urllib.parse
import re
import requests

def format_e164_phone(phone: str) -> str:
    """Format input phone number into clean E.164 format (+XXXXXXXXXXX)."""
    if not phone:
        return ""
    clean = re.sub(r'[^\d+]', '', str(phone).strip())
    if not clean:
        return ""
    if clean.startswith('+'):
        return clean
    if len(clean) == 10:
        return f"+91{clean}"
    return f"+{clean}"


class BaseSMSProvider:
    def send(self, to_number: str, message: str) -> tuple[bool, str]:
        raise NotImplementedError

class ConsoleSMSProvider(BaseSMSProvider):
    def send(self, to_number: str, message: str) -> tuple[bool, str]:
        formatted = format_e164_phone(to_number)
        print(f"[SMS LOG] To: {formatted or to_number} | Message: {message}", flush=True)
        return True, ""

class TwilioSMSProvider(BaseSMSProvider):
    def __init__(self):
        self.account_sid = getattr(settings, 'TWILIO_ACCOUNT_SID', None)
        self.auth_token = getattr(settings, 'TWILIO_AUTH_TOKEN', None)
        self.from_number = getattr(settings, 'TWILIO_FROM_NUMBER', None)

    def send(self, to_number: str, message: str) -> tuple[bool, str]:
        if not self.account_sid or not self.auth_token:
            return False, "Twilio credentials not configured"
        formatted_phone = format_e164_phone(to_number)
        if not formatted_phone:
            return False, f"Invalid phone number: {to_number}"
        try:
            from twilio.rest import Client
            client = Client(self.account_sid, self.auth_token)
            msg = client.messages.create(
                body=message,
                from_=self.from_number,
                to=formatted_phone
            )
            return True, msg.sid
        except Exception as e:
            return False, str(e)


class TextBeeSMSProvider(BaseSMSProvider):
    def __init__(self):
        self.api_key = getattr(settings, 'TEXTBEE_API_KEY', '')
        self.device_id = getattr(settings, 'TEXTBEE_DEVICE_ID', '')
        self.base_url = getattr(settings, 'TEXTBEE_BASE_URL', 'https://api.textbee.dev/api/v1').rstrip('/')

    def send(self, to_number: str, message: str) -> tuple[bool, str]:
        if not self.api_key or not self.device_id:
            return False, "TextBee API key or Device ID not configured"

        formatted_phone = format_e164_phone(to_number)
        if not formatted_phone:
            return False, f"Invalid phone number: {to_number}"

        encoded_dev_id = urllib.parse.quote(self.device_id)
        url = f"{self.base_url}/gateway/devices/{encoded_dev_id}/send-sms"
        headers = {
            "x-api-key": self.api_key,
            "Content-Type": "application/json"
        }
        payload = {
            "recipients": [formatted_phone],
            "message": message
        }

        try:
            res = requests.post(url, json=payload, headers=headers, timeout=10)
            if res.status_code in (200, 201):
                try:
                    data = res.json()
                    msg_id = data.get('id') or data.get('_id') or data.get('message') or "SUCCESS"
                except Exception:
                    msg_id = "SUCCESS"
                print(_safe_str(f"[TEXTBEE SMS SUCCESS] Sent to {formatted_phone}: {message}"))
                return True, str(msg_id)
            else:
                err_msg = f"TextBee HTTP {res.status_code}: {res.text}"
                logger.error(err_msg)
                print(_safe_str(f"[TEXTBEE SMS ERROR] {err_msg}"))
                return False, err_msg
        except Exception as e:
            err_msg = f"TextBee SMS Exception: {str(e)}"
            logger.error(err_msg)
            print(_safe_str(f"[TEXTBEE SMS EXCEPTION] {e}"))
            return False, err_msg


class SMSService:
    """
    Pluggable SMS Service class supporting TextBee, Twilio, and Console logging.
    Logs SMS to console/external service and saves SMSLog & NotificationLog in PostgreSQL.
    """
    _provider = None

    @classmethod
    def get_provider(cls):
        provider_name = getattr(settings, 'SMS_PROVIDER', 'CONSOLE').upper()
        if provider_name == 'TEXTBEE':
            return TextBeeSMSProvider()
        elif provider_name == 'TWILIO':
            return TwilioSMSProvider()
        else:
            return ConsoleSMSProvider()

    @classmethod
    def send_sms(cls, to_number: str, message: str, user=None) -> bool:
        if not to_number:
            return False

        formatted_recipient = format_e164_phone(to_number)
        provider = cls.get_provider()
        provider_name = getattr(settings, 'SMS_PROVIDER', 'CONSOLE').upper()
        success, err = provider.send(to_number, message)

        # Store SMS Log in PostgreSQL DB
        try:
            SMSLog.objects.create(
                user=user,
                to_number=formatted_recipient or to_number,
                message=message,
                provider=provider_name,
                status='SENT' if success else 'FAILED',
                error_message=err if err else None
            )
        except Exception as e:
            logger.error(f"Failed to record SMSLog: {e}")

        try:
            NotificationLog.objects.create(
                user=user,
                channel='SMS',
                status='SUCCESS' if success else 'FAILURE',
                recipient=formatted_recipient or to_number,
                title='',
                message=message,
                error_message=err if err else None
            )
        except Exception as e:
            logger.error(f"Failed to record NotificationLog: {e}")

        return success



# ---------------------------------------------------------------------------
# Core Notification Functions
# ---------------------------------------------------------------------------

def send_push(user, title: str, body: str, data: dict = None) -> bool:
    """
    Send FCM push notification to a user's registered Android devices.
    """
    if not user:
        return False

    devices = FCMDevice.objects.filter(user=user)
    if not devices.exists():
        print(_safe_str(f"[FCM] Warning: No device token for {user.email}"))
        NotificationLog.objects.create(
            user=user,
            channel='FCM',
            status='FAILURE',
            recipient=getattr(user, 'email', 'unknown'),
            title=title,
            message=body,
            error_message="No registered FCM device tokens."
        )
        return False

    success_any = False
    data_payload = data or {}

    for dev in devices:
        try:
            if _firebase_initialized and messaging:
                fcm_msg = messaging.Message(
                    notification=messaging.Notification(
                        title=title,
                        body=body
                    ),
                    data={k: str(v) for k, v in data_payload.items()},
                    token=dev.token
                )
                res = messaging.send(fcm_msg)
                print(_safe_str(f"[FCM] Push sent to {user.email}: {res}"))
                success_any = True
                NotificationLog.objects.create(
                    user=user,
                    channel='FCM',
                    status='SUCCESS',
                    recipient=dev.token,
                    title=title,
                    message=body
                )
            else:
                print(_safe_str(f"[MOCK FCM] Push to {user.email} (Token: {dev.token[:12]}...): {title} - {body}"))
                success_any = True
                NotificationLog.objects.create(
                    user=user,
                    channel='FCM',
                    status='SUCCESS',
                    recipient=dev.token,
                    title=title,
                    message=body
                )
        except Exception as e:
            print(_safe_str(f"[FCM] Failed push to {user.email}: {e}"))
            NotificationLog.objects.create(
                user=user,
                channel='FCM',
                status='FAILURE',
                recipient=dev.token,
                title=title,
                message=body,
                error_message=str(e)
            )

    return success_any


def send_email(to_email: str, subject: str, message_body: str, html_message: str = None, user=None) -> bool:
    """
    Send email via Gmail SMTP (or configured EMAIL_BACKEND).
    """
    if not to_email:
        return False

    try:
        from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', settings.EMAIL_HOST_USER)
        if html_message:
            msg = EmailMultiAlternatives(
                subject=subject,
                body=message_body,
                from_email=from_email,
                to=[to_email]
            )
            msg.attach_alternative(html_message, "text/html")
            msg.send(fail_silently=False)
        else:
            send_mail(
                subject=subject,
                message=message_body,
                from_email=from_email,
                recipient_list=[to_email],
                fail_silently=False
            )

        print(_safe_str(f"[EMAIL] Sent email to {to_email}: {subject}"))
        NotificationLog.objects.create(
            user=user,
            channel='EMAIL',
            status='SUCCESS',
            recipient=to_email,
            title=subject,
            message=message_body
        )
        return True
    except Exception as e:
        print(_safe_str(f"[EMAIL] SMTP dispatch failed ({e}) for {to_email}"))
        NotificationLog.objects.create(
            user=user,
            channel='EMAIL',
            status='FAILURE',
            recipient=to_email,
            title=subject,
            message=message_body,
            error_message=str(e)
        )
        return False


# ---------------------------------------------------------------------------
# High-Level SOS Incident Notification Functions
# ---------------------------------------------------------------------------

def notify_guardians(incident) -> int:
    """
    Notify all guardians of the resident when an SOS is created.
    Sends In-App Notification, Email (Subject: 'Emergency SOS Alert'), Push, and SMS.
    Guarantees in-app Notification record in PostgreSQL for every linked guardian.
    """
    from emergency.models import ResidentGuardian, Guardian, EmergencyContact

    resident = incident.resident
    count = 0
    notified_emails = set()

    # 1. ResidentGuardian linked accounts (Both Primary & Secondary)
    links = ResidentGuardian.objects.filter(resident=resident, status='Active').select_related('guardian')
    for link in links:
        guardian_user = link.guardian
        if not guardian_user:
            continue

        # GUARANTEE In-App Notification record for guardian_user
        Notification.objects.create(
            user=guardian_user,
            title="🚨 Emergency SOS Alert",
            message=f"SOS alert from {resident.full_name}: {incident.message or 'Immediate assistance required.'}",
            category="sos",
            incident=incident,
            priority=incident.priority or "HIGH"
        )

        if guardian_user.email and guardian_user.email not in notified_emails:
            notified_emails.add(guardian_user.email)
            _send_guardian_sos_email(guardian_user.email, incident, guardian_user.full_name, user=guardian_user)

        send_push(
            user=guardian_user,
            title="Emergency SOS Alert",
            body=f"{resident.full_name} triggered an SOS emergency alert!",
            data={
                "incident_id": str(incident.id),
                "resident_name": resident.full_name,
                "category": incident.category.name if incident.category else "SOS",
                "click_action": "FLUTTER_NOTIFICATION_CLICK"
            }
        )

        if guardian_user.phone_number:
            sms_text = f"EMERGENCY SOS: {resident.full_name} requested assistance at {incident.address or 'Unknown location'}. Message: {incident.message or 'None'}"
            SMSService.send_sms(guardian_user.phone_number, sms_text, user=guardian_user)

        count += 1

    # 2. EmergencyContact entries
    contacts = EmergencyContact.objects.filter(resident=resident)
    for contact in contacts:
        if contact.email and contact.email not in notified_emails:
            notified_emails.add(contact.email)
            _send_guardian_sos_email(contact.email, incident, contact.name)
            count += 1
        if contact.phone:
            sms_text = f"EMERGENCY SOS: {resident.full_name} requested assistance at {incident.address or 'Unknown location'}."
            SMSService.send_sms(contact.phone, sms_text)

    # 3. Guardian entries
    guardians_tbl = Guardian.objects.filter(resident=resident)
    for g in guardians_tbl:
        if g.phone:
            sms_text = f"EMERGENCY SOS: {resident.full_name} requested assistance at {incident.address or 'Unknown location'}."
            SMSService.send_sms(g.phone, sms_text)

    return count



def _send_guardian_sos_email(to_email: str, incident, guardian_name: str = 'Guardian', user=None) -> bool:
    """Helper to structure and send SOS email with required fields."""
    resident_name = incident.resident.full_name if incident.resident else 'Resident'
    category_name = incident.category.name if incident.category else 'SOS Emergency'
    address = incident.address if incident.address and incident.address.strip() else 'Location unavailable'
    time_str = incident.created_at.strftime('%Y-%m-%d %H:%M:%S UTC') if incident.created_at else 'Just now'
    emergency_msg = incident.emergency_description or incident.message or 'Immediate assistance requested.'

    subject = "Emergency SOS Alert"
    body = (
        f"EMERGENCY SOS ALERT\n\n"
        f"Dear {guardian_name},\n\n"
        f"An emergency SOS alert has been triggered on CareConnect!\n\n"
        f"Resident Name: {resident_name}\n"
        f"Category: {category_name}\n"
        f"Address: {address}\n"
        f"Time: {time_str}\n"
        f"Emergency Message: {emergency_msg}\n\n"
        f"Please check the CareConnect Mobile App immediately to respond."
    )

    html = (
        f"<div style='font-family: Arial, sans-serif; padding: 20px; background-color: #fff1f2; border: 2px solid #ef4444; border-radius: 12px;'>"
        f"<h2 style='color: #dc2626;'>🚨 EMERGENCY SOS ALERT</h2>"
        f"<p>Dear <strong>{guardian_name}</strong>,</p>"
        f"<p>An emergency SOS alert was triggered on CareConnect.</p>"
        f"<table style='width: 100%; border-collapse: collapse; margin-top: 15px;'>"
        f"<tr><td style='padding: 8px; font-weight: bold;'>Resident Name:</td><td style='padding: 8px;'>{resident_name}</td></tr>"
        f"<tr><td style='padding: 8px; font-weight: bold;'>Category:</td><td style='padding: 8px;'>{category_name}</td></tr>"
        f"<tr><td style='padding: 8px; font-weight: bold;'>Address:</td><td style='padding: 8px;'>{address}</td></tr>"
        f"<tr><td style='padding: 8px; font-weight: bold;'>Time:</td><td style='padding: 8px;'>{time_str}</td></tr>"
        f"<tr><td style='padding: 8px; font-weight: bold;'>Emergency Message:</td><td style='padding: 8px; color: #dc2626;'>{emergency_msg}</td></tr>"
        f"</table>"
        f"<p style='margin-top: 20px;'>Open your CareConnect mobile app immediately to coordinate assistance.</p>"
        f"</div>"
    )

    return send_email(to_email, subject, body, html_message=html, user=user)


def notify_security(incident) -> int:
    """
    Notify all security guards and society admins for an SOS incident.
    """
    resident = incident.resident
    society = getattr(resident, 'society', None)
    
    security_users = User.objects.filter(role__in=['SECURITY', 'ADMIN', 'SOCIETY_MANAGER'])
    if society:
        security_users = security_users.filter(society=society)

    count = 0
    for user in security_users:
        Notification.objects.create(
            user=user,
            title="🚨 SECURITY ALERT: SOS Triggered",
            message=f"{resident.full_name} ({resident.flat_number or 'Resident'}) triggered SOS at {incident.address or 'Society premises'}.",
            category="SOS",
            incident=incident,
            priority="CRITICAL"
        )
        send_push(
            user=user,
            title="SECURITY ALERT: SOS",
            body=f"{resident.full_name} triggered an SOS emergency!",
            data={"incident_id": str(incident.id)}
        )
        if user.phone_number:
            SMSService.send_sms(user.phone_number, f"SECURITY ALERT: SOS triggered by {resident.full_name} at {incident.address or 'unknown'}", user=user)
        count += 1

    return count


def notify_volunteers(incident) -> int:
    """
    Notify active community volunteers about an emergency SOS.
    """
    volunteers = User.objects.filter(role='VOLUNTEER', is_active=True)
    count = 0
    for vol in volunteers:
        Notification.objects.create(
            user=vol,
            title="🤝 Volunteer Emergency Assistance Needed",
            message=f"A nearby resident ({incident.resident.full_name}) requested emergency assistance.",
            category="SOS",
            incident=incident,
            priority="HIGH"
        )
        send_push(
            user=vol,
            title="Volunteer Assistance Needed",
            body=f"SOS alert near you: {incident.category.name if incident.category else 'Emergency'}",
            data={"incident_id": str(incident.id)}
        )
        count += 1
    return count
