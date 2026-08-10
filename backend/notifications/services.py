import logging
import os
import requests
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from django.conf import settings
from .models import Notification, FCMDevice, NotificationTemplate, NotificationLog
from .notification_service import (
    SMSService,
    TextBeeSMSProvider,
    TwilioSMSProvider,
    ConsoleSMSProvider,
    format_e164_phone,
    send_email,
    send_push,
    _safe_str
)

# Firebase Admin SDK imports
try:
    import firebase_admin
    from firebase_admin import credentials, messaging
except ImportError:
    firebase_admin = None
    credentials = None
    messaging = None

logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK if service account is available
_firebase_initialized = False
if firebase_admin:
    try:
        service_account_path = getattr(settings, 'FIREBASE_SERVICE_ACCOUNT_PATH', None)
        if service_account_path and os.path.exists(service_account_path):
            if not firebase_admin._apps:
                cred = credentials.Certificate(service_account_path)
                firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK initialized successfully.")
        else:
            logger.warning("Firebase service account not configured. FCM will use mock mode.")
    except Exception as e:
        logger.error(f"Failed to initialize Firebase Admin SDK: {e}")
        _firebase_initialized = False


class NotificationEngineService:
    """
    Business-logic service layer for Notification dispatches (FCM, Email, SMS, In-App).
    """


    @staticmethod
    def register_device_token(user, token: str) -> FCMDevice:
        """Register or update a user's FCM device token."""
        device, created = FCMDevice.objects.update_or_create(
            token=token,
            defaults={'user': user}
        )
        return device

    @staticmethod
    def send_fcm(user, title: str, message: str, data: dict = None) -> bool:
        """Send real FCM push notifications using Firebase Admin SDK (or mock if not configured)."""
        devices = FCMDevice.objects.filter(user=user)
        if not devices.exists():
            NotificationLog.objects.create(
                user=user,
                channel='FCM',
                status='FAILURE',
                recipient=user.email,
                title=title,
                message=message,
                error_message="No registered FCM devices found for user."
            )
            print(_safe_str(f"[FCM] Warning: No device token for {user.email}"))
            return False

        success = True
        tokens_to_remove = []
        
        for dev in devices:
            try:
                if _firebase_initialized and messaging:
                    # Build message
                    fcm_message = messaging.Message(
                        notification=messaging.Notification(
                            title=title,
                            body=message
                        ),
                        data=data or {},
                        token=dev.token
                    )
                    
                    # Send message
                    response = messaging.send(fcm_message)
                    print(_safe_str(f"[FCM] Successfully sent push to {user.email}: {response}"))
                    NotificationLog.objects.create(
                        user=user,
                        channel='FCM',
                        status='SUCCESS',
                        recipient=dev.token,
                        title=title,
                        message=message
                    )
                else:
                    # Mock sending
                    print(_safe_str(f"[MOCK FCM] Sending push to {user.email} (Token: {dev.token[:12]}...): {title} - {message}"))
                    NotificationLog.objects.create(
                        user=user,
                        channel='FCM',
                        status='SUCCESS',
                        recipient=dev.token,
                        title=title,
                        message=message
                    )
            except messaging.UnregisteredError:
                # Token is invalid/expired, mark for removal
                print(_safe_str(f"[FCM] Token is unregistered, removing: {dev.token[:12]}..."))
                tokens_to_remove.append(dev)
                success = False
                NotificationLog.objects.create(
                    user=user,
                    channel='FCM',
                    status='FAILURE',
                    recipient=dev.token,
                    title=title,
                    message=message,
                    error_message="Unregistered token"
                )
            except Exception as e:
                success = False
                print(_safe_str(f"[FCM] Failed to send push to {user.email}: {e}"))
                NotificationLog.objects.create(
                    user=user,
                    channel='FCM',
                    status='FAILURE',
                    recipient=dev.token,
                    title=title,
                    message=message,
                    error_message=str(e)
                )
        
        # Remove invalid tokens
        if tokens_to_remove:
            for dev in tokens_to_remove:
                dev.delete()
            print(_safe_str(f"[FCM] Removed {len(tokens_to_remove)} invalid FCM tokens"))
        
        return success

    @staticmethod
    def send_email(email: str, title: str, message: str, html_message: str = None, user=None) -> bool:
        """Send email with optional HTML content."""
        try:
            from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', 'chandrakanthreddyy687@gmail.com')
            if html_message:
                # Send email with HTML and plain text fallback
                msg = EmailMultiAlternatives(
                    subject=title,
                    body=message,
                    from_email=from_email,
                    to=[email]
                )
                msg.attach_alternative(html_message, "text/html")
                msg.send(fail_silently=False)
            else:
                # Send plain text email
                from django.core.mail import send_mail
                send_mail(
                    subject=title,
                    message=message,
                    from_email=from_email,
                    recipient_list=[email],
                    fail_silently=False,
                )
            print(_safe_str(f"[EMAIL] Sent real email to {email}: {title}"))
            NotificationLog.objects.create(
                user=user,
                channel='EMAIL',
                status='SUCCESS',
                recipient=email,
                title=title,
                message=message
            )
            return True
        except Exception as e:
            # Log real failure when SMTP dispatch fails
            print(_safe_str(f"[EMAIL] SMTP dispatch failed ({e}): {title} - {message}"))
            NotificationLog.objects.create(
                user=user,
                channel='EMAIL',
                status='FAILURE',
                recipient=email,
                title=title,
                message=message,
                error_message=str(e)
            )
            return False

    @staticmethod
    def send_sos_email(email: str, incident, user=None) -> bool:
        """Send SOS-specific HTML email notification."""
        try:
            resident_name = incident.resident.full_name if incident.resident else 'Unknown Resident'
            emergency_category = incident.category.name if incident.category else 'SOS'
            priority = incident.priority or 'MEDIUM'
            triggered_time = incident.created_at.strftime('%Y-%m-%d %H:%M:%S UTC') if incident.created_at else 'Unknown'
            address = incident.address or 'Address not available'
            coordinates = f"{incident.latitude}, {incident.longitude}" if (incident.latitude and incident.longitude) else 'Coordinates not available'
            google_maps_link = f"https://www.google.com/maps/search/?api=1&query={incident.latitude},{incident.longitude}" if (incident.latitude and incident.longitude) else None
            message = incident.message or ''
            status = incident.status or 'Pending'

            # Build context for template
            context = {
                'resident_name': resident_name,
                'emergency_category': emergency_category,
                'priority': priority,
                'triggered_time': triggered_time,
                'address': address,
                'coordinates': coordinates,
                'message': message,
                'status': status,
                'google_maps_link': google_maps_link
            }

            # Render HTML and plain text content
            html_content = render_to_string('emails/sos_alert.html', context)
            plain_text_content = strip_tags(html_content)
            subject = "🚨 CareConnect SOS Alert"

            # Send email
            return NotificationEngineService.send_email(
                email=email,
                title=subject,
                message=plain_text_content,
                html_message=html_content,
                user=user
            )
        except Exception as e:
            print(_safe_str(f"[EMAIL] Failed to send SOS email to {email}: {e}"))
            NotificationLog.objects.create(
                user=user,
                channel='EMAIL',
                status='FAILURE',
                recipient=email,
                title="🚨 CareConnect SOS Alert",
                message=f"SOS email failed for incident {incident.id if incident else 'unknown'}",
                error_message=str(e)
            )
            return False


    @staticmethod
    def send_sms(phone: str, message: str, user=None) -> bool:
        """Dispatches SMS via configured SMSService provider (TextBee / Twilio / Console)."""
        return SMSService.send_sms(phone, message, user=user)


    @classmethod
    def dispatch_notification(cls, user, title: str, message: str, category: str = 'general', incident=None, channels=None, priority='LOW') -> Notification:
        """
        Main entry point to dispatch notifications app-wide.
        Automatically routes across In-App, FCM, Email, and SMS.
        """
        if channels is None:
            channels = ['IN_APP', 'FCM', 'EMAIL', 'SMS']

        # Build FCM data payload if incident is provided
        fcm_data = {}
        if incident:
            fcm_data = {
                'incident_id': str(incident.id),
                'resident_name': incident.resident.full_name if incident.resident else '',
                'emergency_category': incident.category.name if incident.category else '',
                'priority': priority,
                'address': incident.address or '',
                'latitude': str(incident.latitude) if incident.latitude else '',
                'longitude': str(incident.longitude) if incident.longitude else '',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK'
            }

        # 1. In-App Notification (always saved in Notification table)
        notif = None
        if 'IN_APP' in channels:
            notif = Notification.objects.create(
                user=user,
                title=title,
                message=message,
                category=category,
                incident=incident,
                is_read=False,
                priority=priority,
                location=f"{incident.latitude},{incident.longitude}" if (incident and incident.latitude and incident.longitude) else (incident.address if incident else '')
            )
            NotificationLog.objects.create(
                user=user,
                channel='IN_APP',
                status='SUCCESS',
                recipient=user.email,
                title=title,
                message=message
            )

        # Apply custom template substitution if one exists
        template = NotificationTemplate.objects.filter(name=category).first()
        if template:
            # Simple variables replacement
            ctx = {
                'user': user.full_name,
                'email': user.email,
                'title': title,
                'message': message,
                'incident_id': str(incident.id) if incident else ''
            }
            try:
                title = template.title_template.format(**ctx)
                message = template.message_template.format(**ctx)
            except Exception as e:
                logger.warning(f"Failed to format template {template.name}: {e}")

        # 2. Push Notification
        if 'FCM' in channels:
            cls.send_fcm(user, title, message, data=fcm_data)

        # 3. Email Notification
        if 'EMAIL' in channels and user.email:
            cls.send_email(user.email, title, message, user=user)

        # 4. SMS Notification
        if 'SMS' in channels and user.phone_number:
            cls.send_sms(user.phone_number, message, user=user)

        return notif
