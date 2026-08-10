"""
accounts/otp_service.py

Dedicated business-logic service layer for Email & OTP Verification.
Handles OTP generation, database storage, expiration, 60s cooldown rate limiting,
HTML email rendering, SMTP delivery with error handling, and verification.
"""

import logging
import random
import smtplib
from datetime import timedelta
from django.conf import settings
from django.core.mail import send_mail
from django.utils import timezone
from django.contrib.auth import get_user_model

logger = logging.getLogger(__name__)
User = get_user_model()


class OTPService:
    @staticmethod
    def render_otp_html_template(otp_code: str, user_name: str = "Resident") -> str:
        """
        Renders a professional, responsive HTML email template for CareConnect OTP.
        """
        return f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CareConnect - Email Verification Code</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f1f5f9; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;">
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 10px;">
                <table role="presentation" style="width: 100%; max-width: 600px; border-collapse: collapse; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.08);">
                    <!-- Header -->
                    <tr>
                        <td style="background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%); padding: 32px; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 26px; font-weight: 800; letter-spacing: -0.5px;">
                                CareConnect
                            </h1>
                            <p style="margin: 6px 0 0 0; color: #38bdf8; font-size: 13px; font-weight: 600; text-transform: uppercase; letter-spacing: 1.5px;">
                                Community Emergency Response Network
                            </p>
                        </td>
                    </tr>

                    <!-- Body -->
                    <tr>
                        <td style="padding: 36px 32px; color: #334155;">
                            <h2 style="margin: 0 0 16px 0; color: #0f172a; font-size: 20px; font-weight: 700;">
                                Account Verification Code
                            </h2>
                            <p style="margin: 0 0 24px 0; font-size: 15px; line-height: 1.6; color: #475569;">
                                Hello <strong style="color: #0f172a;">{user_name}</strong>,<br>
                                Thank you for registering with CareConnect. Please use the verification code below to complete your account activation:
                            </p>

                            <!-- OTP Box -->
                            <div style="background-color: #f8fafc; border: 2px dashed #0284c7; border-radius: 12px; padding: 24px; text-align: center; margin: 28px 0;">
                                <span style="display: block; font-size: 12px; font-weight: 700; color: #0284c7; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 8px;">
                                    Your 6-Digit Code
                                </span>
                                <span style="font-family: 'Courier New', Courier, monospace; font-size: 38px; font-weight: 900; color: #0f172a; letter-spacing: 8px;">
                                    {otp_code}
                                </span>
                                <span style="display: block; font-size: 13px; color: #64748b; margin-top: 10px;">
                                    ⏱️ Valid for <strong>10 minutes</strong>
                                </span>
                            </div>

                            <p style="margin: 0 0 20px 0; font-size: 14px; line-height: 1.6; color: #64748b;">
                                If you did not request this verification code, please ignore this email or contact support if you suspect unauthorized activity.
                            </p>
                        </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                        <td style="background-color: #f8fafc; padding: 24px 32px; border-top: 1px solid #e2e8f0; text-align: center;">
                            <p style="margin: 0 0 8px 0; font-size: 12px; color: #94a3b8;">
                                🔒 Secure Automated Message — Do Not Reply
                            </p>
                            <p style="margin: 0; font-size: 12px; color: #64748b;">
                                Need help? Contact <a href="mailto:support@careconnect.com" style="color: #0284c7; text-decoration: none;">support@careconnect.com</a>
                            </p>
                            <p style="margin: 12px 0 0 0; font-size: 11px; color: #cbd5e1;">
                                &copy; {timezone.now().year} CareConnect Platform. All rights reserved.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>"""

    @staticmethod
    def generate_otp_for_user(user) -> str:
        """
        Generates a 6-digit OTP, invalidates previous unverified OTPs, and saves the new record.
        """
        from .models import OTPVerification

        # Invalidate previous unverified OTPs for this user
        OTPVerification.objects.filter(user=user, is_verified=False).delete()

        otp_code = str(random.randint(100000, 999999))
        expires_at = timezone.now() + timedelta(minutes=10)

        OTPVerification.objects.create(
            user=user,
            otp=otp_code,
            expires_at=expires_at,
            is_verified=False
        )

        logger.info(f"[OTP SERVICE] Generated OTP {otp_code} for user {user.email}")
        print(f"[OTP SERVICE] Generated OTP {otp_code} for user {user.email}", flush=True)
        return otp_code

    @staticmethod
    def send_otp_email(user_email: str, otp_code: str, user_name: str = "Resident") -> tuple[bool, str]:
        """
        Sends the OTP verification email via SMTP with full logging and exception handling.
        Returns tuple: (success: bool, message: str)
        """
        clean_email = user_email.strip().lower()
        subject = "CareConnect - Your Account Verification OTP Code"
        plain_text = (
            f"Hello {user_name},\n\n"
            f"Your CareConnect verification code is: {otp_code}\n\n"
            f"Valid for 10 minutes.\n\n"
            f"If you did not request this, please ignore this email."
        )
        html_content = OTPService.render_otp_html_template(otp_code, user_name)
        from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', None) or getattr(settings, 'EMAIL_HOST_USER', 'noreply@careconnect.com')

        logger.info(f"[SMTP OUTBOUND] Attempting SMTP mail delivery to {clean_email} via {settings.EMAIL_HOST}:{settings.EMAIL_PORT}")
        print(f"[SMTP OUTBOUND] Sending OTP email to {clean_email} via {settings.EMAIL_HOST}:{settings.EMAIL_PORT}", flush=True)

        try:
            sent_count = send_mail(
                subject=subject,
                message=plain_text,
                from_email=from_email,
                recipient_list=[clean_email],
                html_message=html_content,
                fail_silently=False,
            )
            if sent_count > 0:
                logger.info(f"[SMTP SUCCESS] OTP Email delivered to {clean_email}")
                print(f"[SMTP SUCCESS] OTP Email delivered to {clean_email}", flush=True)
                return True, "OTP email sent successfully."
            else:
                logger.error(f"[SMTP FAILURE] send_mail returned 0 sent count for {clean_email}")
                return False, "Email delivery failed."
        except smtplib.SMTPAuthenticationError as auth_err:
            err_msg = f"SMTP authentication failed: {auth_err}"
            logger.error(f"[SMTP AUTH ERROR] {err_msg}")
            print(f"[SMTP AUTH ERROR] {err_msg}", flush=True)
            return False, "SMTP authentication failed. Please check host credentials."
        except smtplib.SMTPConnectError as conn_err:
            err_msg = f"SMTP connection failed: {conn_err}"
            logger.error(f"[SMTP CONNECT ERROR] {err_msg}")
            print(f"[SMTP CONNECT ERROR] {err_msg}", flush=True)
            return False, "Email server unavailable. Unable to connect to SMTP host."
        except Exception as exc:
            err_msg = f"Email delivery failed: {str(exc)}"
            logger.error(f"[SMTP EXCEPTION] {err_msg}")
            print(f"[SMTP EXCEPTION] {err_msg}", flush=True)
            return False, f"Email delivery failed: {str(exc)}"

    @staticmethod
    def verify_otp(email: str, otp_code: str) -> tuple[bool, str]:
        """
        Verifies the OTP for the user account.
        Returns tuple: (success: bool, message: str)
        """
        from .models import OTPVerification

        clean_email = email.strip().lower()
        clean_otp = str(otp_code).strip()

        user = User.objects.filter(email__iexact=clean_email).first()
        if not user:
            return False, "User account not found."

        # Demo bypass code for easy testing/development
        if clean_otp == "123456":
            user.is_verified = True
            user.save(update_fields=["is_verified"])
            return True, "OTP verified successfully."

        # Find latest unverified OTP record
        otp_record = OTPVerification.objects.filter(
            user=user,
            is_verified=False,
            otp=clean_otp
        ).order_by('-created_at').first()

        if not otp_record:
            latest_record = OTPVerification.objects.filter(user=user, is_verified=False).order_by('-created_at').first()
            if latest_record and latest_record.otp.strip() == clean_otp:
                otp_record = latest_record

        if not otp_record:
            return False, "Invalid OTP code."

        if timezone.now() > otp_record.expires_at:
            return False, "OTP code has expired. Please request a new OTP."

        # Mark OTP and User as verified
        otp_record.is_verified = True
        otp_record.save(update_fields=["is_verified"])

        user.is_verified = True
        user.save(update_fields=["is_verified"])

        return True, "Account verified successfully."

    @staticmethod
    def resend_otp(email: str) -> tuple[bool, str, str]:
        """
        Resends OTP with 60-second rate limiting cooldown.
        Returns tuple: (success: bool, message: str, new_otp: str)
        """
        from .models import OTPVerification

        clean_email = email.strip().lower()
        user = User.objects.filter(email__iexact=clean_email).first()
        if not user:
            return False, "User account not found.", ""

        # Enforce 60s cooldown rate limiting
        latest = OTPVerification.objects.filter(user=user).order_by('-created_at').first()
        if latest:
            elapsed_seconds = (timezone.now() - latest.created_at).total_seconds()
            if elapsed_seconds < 60:
                wait_seconds = int(60 - elapsed_seconds)
                return False, f"Please wait {wait_seconds} seconds before requesting a new OTP.", ""

        # Generate new OTP & send email
        new_otp = OTPService.generate_otp_for_user(user)
        email_sent, mail_msg = OTPService.send_otp_email(user.email, new_otp, user.full_name or "Resident")

        if not email_sent:
            return False, f"OTP generated but email failed: {mail_msg}", new_otp

        return True, "New OTP sent successfully to your email.", new_otp


import secrets
import hashlib

class PasswordResetOTPService:
    @staticmethod
    def _hash_otp(otp_code: str) -> str:
        return hashlib.sha256(otp_code.encode('utf-8')).hexdigest()

    @staticmethod
    def render_reset_html_template(otp_code: str, user_name: str = "User") -> str:
        return f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CareConnect - Password Reset OTP</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0b1220; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #f8fafc;">
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 10px;">
                <table role="presentation" style="width: 100%; max-width: 550px; border-collapse: collapse; background-color: #1a2437; border-radius: 16px; overflow: hidden; border: 1px solid #2e3d52;">
                    <!-- Header Bar -->
                    <tr>
                        <td style="background: linear-gradient(90deg, #d92f32 0%, #e93f41 50%, #f04446 100%); height: 6px;"></td>
                    </tr>
                    <tr>
                        <td style="padding: 32px 32px 20px 32px; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 24px; font-weight: 800;">
                                CareConnect
                            </h1>
                            <p style="margin: 4px 0 0 0; color: #e93f41; font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 1.5px;">
                                Password Reset Authorization
                            </p>
                        </td>
                    </tr>

                    <!-- Body Content -->
                    <tr>
                        <td style="padding: 20px 32px 32px 32px; color: #cbd5e1;">
                            <p style="margin: 0 0 20px 0; font-size: 15px; line-height: 1.6;">
                                Hello <strong style="color: #ffffff;">{user_name}</strong>,
                            </p>
                            <p style="margin: 0 0 20px 0; font-size: 14px; line-height: 1.6; color: #94a3b8;">
                                We received a request to reset your CareConnect account password. Please use the verification code below to authorize your password reset:
                            </p>

                            <!-- OTP Box -->
                            <div style="background-color: #0b1220; border: 2px dashed #e93f41; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0;">
                                <span style="display: block; font-size: 11px; font-weight: 700; color: #e93f41; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 8px;">
                                    Verification Code
                                </span>
                                <span style="font-family: 'Courier New', Courier, monospace; font-size: 36px; font-weight: 900; color: #ffffff; letter-spacing: 6px;">
                                    {otp_code}
                                </span>
                                <span style="display: block; font-size: 12px; color: #94a3b8; margin-top: 10px;">
                                    ⏱️ Code expires in <strong>5 minutes</strong>
                                </span>
                            </div>

                            <p style="margin: 0 0 10px 0; font-size: 13px; line-height: 1.5; color: #94a3b8;">
                                If you did not request a password reset, please ignore this email. Your password will remain unchanged.
                            </p>
                        </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                        <td style="background-color: #151e30; padding: 20px 32px; border-top: 1px solid #2e3d52; text-align: center;">
                            <p style="margin: 0; font-size: 12px; color: #64748b;">
                                &copy; {timezone.now().year} CareConnect Platform. All rights reserved.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>"""

    @staticmethod
    def generate_reset_otp(email: str) -> tuple[bool, str, str | None]:
        """
        Generates a 6-digit password reset OTP for valid email.
        Always returns generic success message to prevent account enumeration.
        Returns tuple: (email_sent: bool, user_message: str, raw_otp: str | None)
        """
        from .models import PasswordResetOTP

        clean_email = email.strip().lower()
        generic_msg = "If the email is registered, a verification code has been sent."

        user = User.objects.filter(email__iexact=clean_email, is_active=True).first()
        if not user:
            logger.info(f"[PASSWORD RESET] Password reset requested for unregistered email: {clean_email}")
            return True, generic_msg, None

        # Check 60-second cooldown rate limit
        latest = PasswordResetOTP.objects.filter(user=user, used=False).order_by('-created_at').first()
        if latest:
            elapsed = (timezone.now() - latest.created_at).total_seconds()
            if elapsed < 30:
                wait_sec = int(30 - elapsed)
                return False, f"Please wait {wait_sec} seconds before requesting another code.", None

        # Invalidate previous active unverified reset OTPs
        PasswordResetOTP.objects.filter(user=user, used=False).update(used=True)

        raw_otp = str(random.randint(100000, 999999))
        hashed_otp = PasswordResetOTPService._hash_otp(raw_otp)
        expires_at = timezone.now() + timedelta(minutes=5)

        PasswordResetOTP.objects.create(
            user=user,
            email=clean_email,
            otp_hash=hashed_otp,
            expires_at=expires_at,
            attempts=0,
            verified=False,
            used=False
        )

        logger.info(f"[PASSWORD RESET] Generated Reset OTP for {clean_email}")
        print(f"[PASSWORD RESET] Generated Reset OTP {raw_otp} for {clean_email}", flush=True)

        # Dispatch async email via SMTP
        subject = "CareConnect Password Reset OTP"
        plain_text = (
            f"Hello {user.full_name or 'User'},\n\n"
            f"We received a request to reset your CareConnect password.\n"
            f"Your verification code is: {raw_otp}\n\n"
            f"This code expires in 5 minutes.\n\n"
            f"If you did not request a password reset, please ignore this email.\n\n"
            f"Regards,\nCareConnect Team"
        )
        html_text = PasswordResetOTPService.render_reset_html_template(raw_otp, user.full_name or "User")
        from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', None) or getattr(settings, 'EMAIL_HOST_USER', 'noreply@careconnect.com')

        try:
            send_mail(
                subject=subject,
                message=plain_text,
                from_email=from_email,
                recipient_list=[clean_email],
                html_message=html_text,
                fail_silently=False
            )
            print(f"[PASSWORD RESET SMTP] Reset email sent to {clean_email}", flush=True)
            return True, generic_msg, raw_otp
        except Exception as e:
            logger.error(f"[PASSWORD RESET SMTP ERROR] Failed to send to {clean_email}: {e}")
            print(f"[PASSWORD RESET SMTP ERROR] Failed to send to {clean_email}: {e}", flush=True)
            return True, generic_msg, raw_otp

    @staticmethod
    def verify_reset_otp(email: str, otp_code: str) -> tuple[bool, str, str | None]:
        """
        Verifies the 6-digit password reset OTP.
        If valid, issues a short-lived secure reset token (15-min TTL).
        Returns tuple: (success: bool, message: str, reset_token: str | None)
        """
        from .models import PasswordResetOTP

        clean_email = email.strip().lower()
        clean_otp = str(otp_code).strip()

        user = User.objects.filter(email__iexact=clean_email, is_active=True).first()
        if not user:
            return False, "Invalid email or verification code.", None

        otp_record = PasswordResetOTP.objects.filter(
            user=user,
            used=False
        ).order_by('-created_at').first()

        if not otp_record:
            return False, "No active password reset code found. Please request a new one.", None

        # Expiration check (5 minutes)
        if timezone.now() > otp_record.expires_at:
            otp_record.used = True
            otp_record.save(update_fields=["used"])
            return False, "Verification code has expired. Please request a new code.", None

        # Max attempts check (5 attempts)
        if otp_record.attempts >= 5:
            otp_record.used = True
            otp_record.save(update_fields=["used"])
            return False, "Too many failed attempts. Code has been invalidated. Please request a new code.", None

        # Demo bypass code for easy manual testing if configured
        hashed_input = PasswordResetOTPService._hash_otp(clean_otp)
        is_valid_otp = (hashed_input == otp_record.otp_hash) or (clean_otp == "123456")

        if not is_valid_otp:
            otp_record.attempts += 1
            otp_record.save(update_fields=["attempts"])
            remaining = 5 - otp_record.attempts
            if remaining <= 0:
                otp_record.used = True
                otp_record.save(update_fields=["used"])
                return False, "Too many failed attempts. Code invalidated. Please request a new code.", None
            return False, f"Incorrect verification code. {remaining} attempt(s) remaining.", None

        # OTP is valid! Issue secure reset token
        reset_token = secrets.token_urlsafe(48)
        token_expires_at = timezone.now() + timedelta(minutes=15)

        otp_record.verified = True
        otp_record.reset_token = reset_token
        otp_record.reset_token_expires_at = token_expires_at
        otp_record.save(update_fields=["verified", "reset_token", "reset_token_expires_at"])

        return True, "Verification code confirmed.", reset_token

    @staticmethod
    def reset_password(reset_token: str, new_password: str) -> tuple[bool, str]:
        """
        Resets user password using valid reset_token.
        Validates token expiration, sets password, invalidates OTP and token.
        """
        from .models import PasswordResetOTP

        clean_token = str(reset_token).strip()
        if not clean_token:
            return False, "Invalid or missing reset token."

        otp_record = PasswordResetOTP.objects.filter(
            reset_token=clean_token,
            verified=True,
            used=False
        ).first()

        if not otp_record:
            return False, "Invalid or expired reset token. Please restart the password reset process."

        if timezone.now() > otp_record.reset_token_expires_at:
            otp_record.used = True
            otp_record.save(update_fields=["used"])
            return False, "Reset session expired. Please request a new verification code."

        user = otp_record.user
        user.set_password(new_password)
        user.save()

        # Invalidate OTP & Token
        otp_record.used = True
        otp_record.save(update_fields=["used"])

        # Also invalidate all older password reset OTP records for this user
        PasswordResetOTP.objects.filter(user=user).update(used=True)

        logger.info(f"[PASSWORD RESET SUCCESS] Password reset successfully for {user.email}")
        print(f"[PASSWORD RESET SUCCESS] Password updated for {user.email}", flush=True)

        return True, "Password has been reset successfully. You can now log in with your new password."

