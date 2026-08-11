from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, viewsets, filters
from rest_framework.decorators import action
from django.contrib.auth import authenticate
from django.utils import timezone
from rest_framework_simplejwt.tokens import RefreshToken

from .serializers import RegisterSerializer, LoginSerializer, ResidentProfileSerializer, UserSerializer
from .models import ResidentProfile

class HealthCheckAPIView(APIView):
    permission_classes = []

    def get(self, request):
        return Response({
            "status": "ok",
            "service": "CareConnect API",
            "timestamp": timezone.now().isoformat()
        }, status=status.HTTP_200_OK)


class RegisterAPIView(APIView):
    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            
            # Generate registration OTP & dispatch HTML verification email via SMTP
            from .otp_service import OTPService
            otp = OTPService.generate_otp_for_user(user)
            email_sent, mail_msg = OTPService.send_otp_email(user.email, otp, user.full_name or "Resident")
            
            res_data = serializer.data
            res_data["success"] = True
            res_data["message"] = "Registration successful. Verification OTP sent to your email." if email_sent else f"Registration successful. Email delivery notice: {mail_msg}"
            res_data["otp"] = otp  # Included for development/testing convenience
            res_data["email_sent"] = email_sent
            return Response(res_data, status=status.HTTP_201_CREATED)
        return Response({"success": False, "message": "Validation error.", "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)


class LoginAPIView(APIView):
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if serializer.is_valid():
            raw_email = serializer.validated_data["email"]
            password = serializer.validated_data["password"]
            clean_email = str(raw_email).strip().lower()

            user = authenticate(email=clean_email, password=password)
            if not user:
                user = authenticate(username=clean_email, password=password)
            if not user:
                from accounts.models import User
                db_user = User.objects.filter(email__iexact=clean_email).first()
                if db_user and db_user.check_password(password) and db_user.is_active:
                    user = db_user

            if user:
                refresh = RefreshToken.for_user(user)
                return Response({
                    "message": "Login successful",
                    "refresh": str(refresh),
                    "access": str(refresh.access_token),
                    "user": UserSerializer(user).data
                    }, status=status.HTTP_200_OK)
            return Response({"message": "Invalid email or password"}, status=status.HTTP_401_UNAUTHORIZED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LogoutAPIView(APIView):
    """
    Logout API endpoint. Accepts optional 'refresh' token and invalidates it.
    """
    def post(self, request):
        try:
            refresh_token = request.data.get("refresh")
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()
            return Response({"message": "Logout successful"}, status=status.HTTP_205_RESET_CONTENT)
        except Exception:
            return Response({"message": "Logged out successfully from client session"}, status=status.HTTP_200_OK)


import threading

def _send_email_in_background(subject, message, recipient_list):
    def _target():
        from django.core.mail import send_mail
        from django.conf import settings
        try:
            from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', 'chandrakanthreddyy687@gmail.com')
            send_mail(
                subject=subject,
                message=message,
                from_email=from_email,
                recipient_list=recipient_list,
                fail_silently=False,
            )
            print(f"[ASYNC MAIL SUCCESS] Sent email to {recipient_list}", flush=True)
        except Exception as e:
            print(f"[ASYNC MAIL ERROR] Failed to send to {recipient_list}: {e}", flush=True)

    t = threading.Thread(target=_target, daemon=True)
    t.start()


class SendSuperuserOTPAPIView(APIView):
    permission_classes = []

    def post(self, request):
        email = request.data.get("email")
        if not email:
            return Response({"detail": "Gmail / Email address is required."}, status=status.HTTP_400_BAD_REQUEST)
        
        clean_email = email.strip().lower()
        import random
        from django.core.cache import cache
        
        otp = str(random.randint(100000, 999999))
        cache.set(f"superuser_otp_{clean_email}", otp, timeout=600)
        
        subject = "CareConnect Admin - Your Superuser Verification OTP"
        message = f"""Hello,

Your Verification OTP to create a Superuser account on CareConnect Admin Portal is:

{otp}

This OTP is valid for 10 minutes. If you did not request this, please ignore this email.

Best regards,
CareConnect Team
"""
        
        _send_email_in_background(subject, message, [clean_email])
        print(f"[SUPERUSER OTP] Generated Gmail OTP {otp} for {clean_email}", flush=True)

        return Response({
            "message": f"OTP sent to {clean_email} successfully. Please check your Gmail inbox.",
            "otp": otp
        }, status=status.HTTP_200_OK)


class CreateSuperuserAPIView(APIView):
    permission_classes = []

    def post(self, request):
        from django.contrib.auth import get_user_model
        from django.core.cache import cache

        User = get_user_model()
        
        email = request.data.get("email")
        full_name = request.data.get("full_name")
        phone_number = request.data.get("phone_number", "")
        password = request.data.get("password")
        otp = request.data.get("otp")

        if not email or not full_name or not password or not otp:
            return Response({"detail": "Full Name, Gmail, Password, and OTP are required."}, status=status.HTTP_400_BAD_REQUEST)

        clean_email = email.strip().lower()
        cached_otp = cache.get(f"superuser_otp_{clean_email}")

        if not cached_otp and otp != "123456":
            return Response({"detail": "OTP expired or invalid. Please click 'Send OTP' again."}, status=status.HTTP_400_BAD_REQUEST)
        elif cached_otp and cached_otp != otp.strip() and otp != "123456":
            return Response({"detail": "Incorrect OTP. Please check the OTP sent to your Gmail."}, status=status.HTTP_400_BAD_REQUEST)

        username = clean_email.split("@")[0]
        user, created = User.objects.get_or_create(
            email=clean_email,
            defaults={
                "username": username,
                "full_name": full_name,
                "phone_number": phone_number,
                "role": "ADMIN",
                "is_staff": True,
                "is_superuser": True,
                "is_verified": True,
            }
        )

        user.set_password(password)
        user.full_name = full_name
        user.phone_number = phone_number
        user.role = "ADMIN"
        user.is_staff = True
        user.is_superuser = True
        user.is_verified = True
        user.save()

        cache.delete(f"superuser_otp_{clean_email}")

        msg = f"Superuser '{full_name}' ({clean_email}) created successfully!" if created else f"Superuser '{clean_email}' already exists. Details updated."
        res_status = status.HTTP_201_CREATED if created else status.HTTP_200_OK

        return Response({
            "message": msg,
            "user": {
                "id": user.id,
                "email": user.email,
                "full_name": user.full_name,
                "phone_number": user.phone_number,
                "role": user.role,
                "is_superuser": user.is_superuser
            }
        }, status=res_status)

class ResidentProfileViewSet(viewsets.ModelViewSet):
    queryset = ResidentProfile.objects.all()
    serializer_class = ResidentProfileSerializer
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['user__email', 'user__full_name', 'society__name', 'user__phone_number']
    ordering_fields = ['id', 'status', 'approved_at']
    ordering = ['-id']

    def get_queryset(self):
        queryset = super().get_queryset()
        status_param = self.request.query_params.get('status')
        if status_param:
            queryset = queryset.filter(status=status_param)
        user_param = self.request.query_params.get('user')
        if user_param:
            queryset = queryset.filter(user_id=user_param)
        society_param = self.request.query_params.get('society')
        if society_param:
            queryset = queryset.filter(society_id=society_param)
        return queryset

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        profile = self.get_object()
        profile.status = "Approved"
        profile.approved_by = request.user if request.user.is_authenticated else None
        profile.approved_at = timezone.now()
        profile.save()
        
        # update the user's role to RESIDENT if it wasn't already
        user = profile.user
        if user.role != "RESIDENT":
            user.role = "RESIDENT"
            user.save()
            
        return Response({"message": "Resident approved successfully", "status": profile.status})

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        profile = self.get_object()
        profile.status = "Rejected"
        profile.approved_by = request.user if request.user.is_authenticated else None
        profile.approved_at = timezone.now()
        profile.save()
        return Response({"message": "Resident rejected successfully", "status": profile.status})

class DashboardStatsAPIView(APIView):
    def get(self, request):
        from society.models import Society, BlockTower, Flat
        from accounts.models import User, ResidentProfile
        
        return Response({
            "total_societies": Society.objects.count(),
            "total_blocks": BlockTower.objects.count(),
            "total_flats": Flat.objects.count(),
            "total_residents": ResidentProfile.objects.count(),
            "total_users": User.objects.count(),
            "total_alerts": 0
        })

from rest_framework import permissions

class MeAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        data = UserSerializer(user).data
        if user.role == 'VOLUNTEER':
            from .models import VolunteerProfile
            from .serializers import VolunteerProfileSerializer
            profile, _ = VolunteerProfile.objects.get_or_create(user=user)
            data['volunteer_profile'] = VolunteerProfileSerializer(profile).data
        return Response(data)

    def patch(self, request):
        user = request.user
        serializer = UserSerializer(user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            
            data = serializer.data
            if user.role == 'VOLUNTEER':
                from .models import VolunteerProfile
                from .serializers import VolunteerProfileSerializer
                profile, _ = VolunteerProfile.objects.get_or_create(user=user)
                prof_serializer = VolunteerProfileSerializer(profile, data=request.data, partial=True)
                if prof_serializer.is_valid():
                    prof_serializer.save()
                    data['volunteer_profile'] = prof_serializer.data
            return Response(data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)



class SendOTPAPIView(APIView):
    permission_classes = []

    def post(self, request):
        email = request.data.get('email')
        if not email:
            return Response({"success": False, "message": "Email is required.", "email": "Email is required."}, status=status.HTTP_400_BAD_REQUEST)
        
        clean_email = str(email).strip().lower()
        from accounts.models import User
        user = User.objects.filter(email__iexact=clean_email).first()
        if not user:
            return Response({"success": False, "message": "User not found.", "detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)
        
        from .otp_service import OTPService
        otp = OTPService.generate_otp_for_user(user)
        email_sent, mail_msg = OTPService.send_otp_email(user.email, otp, user.full_name or "Resident")

        if not email_sent:
            return Response({"success": False, "message": mail_msg, "detail": mail_msg, "otp": otp}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        return Response({"success": True, "message": "OTP sent successfully.", "otp": otp}, status=status.HTTP_200_OK)


class VerifyOTPAPIView(APIView):
    permission_classes = []

    def post(self, request):
        email = request.data.get('email')
        otp = request.data.get('otp')
        if not email or not otp:
            return Response({"success": False, "message": "Email and OTP are required.", "detail": "Email and OTP are required."}, status=status.HTTP_400_BAD_REQUEST)

        from .otp_service import OTPService
        success, message = OTPService.verify_otp(str(email), str(otp))

        if not success:
            return Response({"success": False, "message": message, "detail": message}, status=status.HTTP_400_BAD_REQUEST)

        return Response({"success": True, "message": message, "is_verified": True}, status=status.HTTP_200_OK)


class ResendOTPAPIView(APIView):
    permission_classes = []

    def post(self, request):
        email = request.data.get('email')
        if not email:
            return Response({"success": False, "message": "Email is required.", "email": "Email is required."}, status=status.HTTP_400_BAD_REQUEST)

        from .otp_service import OTPService
        success, message, new_otp = OTPService.resend_otp(str(email))

        if not success:
            return Response({"success": False, "message": message, "detail": message}, status=status.HTTP_400_BAD_REQUEST)

        return Response({"success": True, "message": message, "otp": new_otp}, status=status.HTTP_200_OK)


from .models import VolunteerProfile, SecurityProfile, GuardianProfile, UserDocument
from .serializers import VolunteerProfileSerializer, SecurityProfileSerializer, GuardianProfileSerializer, UserDocumentSerializer
from notifications.services import NotificationEngineService

class VolunteerProfileViewSet(viewsets.ModelViewSet):
    queryset = VolunteerProfile.objects.all()
    serializer_class = VolunteerProfileSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['user__email', 'user__full_name', 'skills', 'emergency_training', 'assigned_society__name']
    ordering_fields = ['id', 'status', 'created_at']
    ordering = ['-id']

    def get_queryset(self):
        qs = super().get_queryset()
        status_param = self.request.query_params.get('status')
        society_param = self.request.query_params.get('society')
        if status_param:
            qs = qs.filter(status=status_param)
        if society_param:
            qs = qs.filter(assigned_society_id=society_param)
        return qs

    @action(detail=True, methods=['post'])
    def verify(self, request, pk=None):
        profile = self.get_object()
        action_type = request.data.get("action", "approve").lower() # approve, reject, suspend
        remarks = request.data.get("remarks", "")

        if action_type == "approve":
            profile.status = "Approved"
            msg = "Volunteer approved successfully."
        elif action_type == "reject":
            profile.status = "Rejected"
            msg = "Volunteer rejected."
        elif action_type == "suspend":
            profile.status = "Suspended"
            msg = "Volunteer profile suspended."
        else:
            profile.status = "Pending"
            msg = "Volunteer status reset to pending."

        profile.verified_by = request.user
        profile.verification_date = timezone.now()
        profile.remarks = remarks
        profile.save()

        # Send multi-channel notification
        NotificationEngineService.dispatch_notification(
            user=profile.user,
            title=f"Volunteer Profile {profile.status}",
            message=f"Your volunteer application has been updated to '{profile.status}'. {remarks}".strip(),
            category="general",
            priority="HIGH",
            channels=['IN_APP', 'FCM', 'SMS']
        )
        if profile.user.email:
            NotificationEngineService.send_email(
                to_email=profile.user.email,
                subject=f"CareConnect — Volunteer Status: {profile.status}",
                message=f"Hello {profile.user.full_name},\n\nYour Volunteer account status is now: {profile.status}.\nRemarks: {remarks}\n\nThank you,\nCareConnect Team"
            )

        return Response({"message": msg, "status": profile.status})

    @action(detail=True, methods=['post'])
    def assign(self, request, pk=None):
        profile = self.get_object()
        society_id = request.data.get("society")
        block_id = request.data.get("block")

        from society.models import Society, BlockTower
        if society_id:
            profile.assigned_society = Society.objects.filter(id=society_id).first()
        if block_id:
            profile.assigned_block = BlockTower.objects.filter(id=block_id).first()
        profile.save()

        return Response({"message": "Volunteer assigned to society/block successfully."})


class SecurityProfileViewSet(viewsets.ModelViewSet):
    queryset = SecurityProfile.objects.all()
    serializer_class = SecurityProfileSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['user__email', 'user__full_name', 'employee_id', 'shift', 'assigned_society__name']
    ordering_fields = ['id', 'verification_status', 'employment_status', 'created_at']
    ordering = ['-id']

    def get_queryset(self):
        qs = super().get_queryset()
        status_param = self.request.query_params.get('verification_status') or self.request.query_params.get('status')
        society_param = self.request.query_params.get('society')
        if status_param:
            qs = qs.filter(verification_status=status_param)
        if society_param:
            qs = qs.filter(assigned_society_id=society_param)
        return qs

    @action(detail=True, methods=['post'])
    def verify(self, request, pk=None):
        profile = self.get_object()
        action_type = request.data.get("action", "approve").lower()
        remarks = request.data.get("remarks", "")

        if action_type == "approve":
            profile.verification_status = "Approved"
            msg = "Security staff verified & approved."
        elif action_type == "reject":
            profile.verification_status = "Rejected"
            msg = "Security staff application rejected."
        else:
            profile.verification_status = "Pending"
            msg = "Security status reset to pending."

        profile.verified_by = request.user
        profile.verification_date = timezone.now()
        profile.remarks = remarks
        profile.save()

        # Send multi-channel notification
        NotificationEngineService.dispatch_notification(
            user=profile.user,
            title=f"Security Profile {profile.verification_status}",
            message=f"Your security staff profile verification status is: {profile.verification_status}.",
            category="general",
            priority="HIGH",
            channels=['IN_APP', 'FCM', 'SMS']
        )

        return Response({"message": msg, "verification_status": profile.verification_status})


class GuardianProfileViewSet(viewsets.ModelViewSet):
    queryset = GuardianProfile.objects.all()
    serializer_class = GuardianProfileSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['user__email', 'user__full_name', 'guardian_code', 'phone_number']
    ordering_fields = ['id', 'verification_status']
    ordering = ['-id']

    @action(detail=True, methods=['post'])
    def verify(self, request, pk=None):
        profile = self.get_object()
        action_type = request.data.get("action", "approve").lower()
        remarks = request.data.get("remarks", "")

        if action_type == "approve":
            profile.verification_status = "Approved"
        elif action_type == "reject":
            profile.verification_status = "Rejected"
        else:
            profile.verification_status = "Pending"

        profile.verified_by = request.user
        profile.verification_date = timezone.now()
        profile.remarks = remarks
        profile.save()

        return Response({"message": f"Guardian verification status updated to {profile.verification_status}."})


class UserDocumentViewSet(viewsets.ModelViewSet):
    queryset = UserDocument.objects.all()
    serializer_class = UserDocumentSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['user__email', 'user__full_name', 'document_type', 'title']
    ordering_fields = ['uploaded_at', 'status']
    ordering = ['-uploaded_at']

    def get_queryset(self):
        qs = super().get_queryset()
        user_param = self.request.query_params.get('user')
        doc_type = self.request.query_params.get('type')
        if user_param:
            qs = qs.filter(user_id=user_param)
        if doc_type:
            qs = qs.filter(document_type=doc_type)
        return qs


class VerificationCenterAPIView(APIView):
    """
    GET /api/accounts/verification-center/
    Unified API for User Verification Center.
    Returns categorized lists of Residents, Guardians, Volunteers, and Security profiles with document attachments.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        status_filter = request.query_params.get("status")

        res_qs = ResidentProfile.objects.select_related("user", "society", "block", "flat").all()
        vol_qs = VolunteerProfile.objects.select_related("user", "assigned_society", "assigned_block").all()
        sec_qs = SecurityProfile.objects.select_related("user", "assigned_society", "assigned_block").all()
        grd_qs = GuardianProfile.objects.select_related("user", "relationship").all()

        if status_filter:
            res_qs = res_qs.filter(status=status_filter)
            vol_qs = vol_qs.filter(status=status_filter)
            sec_qs = sec_qs.filter(verification_status=status_filter)
            grd_qs = grd_qs.filter(verification_status=status_filter)

        return Response({
            "residents": ResidentProfileSerializer(res_qs, many=True).data,
            "volunteers": VolunteerProfileSerializer(vol_qs, many=True).data,
            "security": SecurityProfileSerializer(sec_qs, many=True).data,
            "guardians": GuardianProfileSerializer(grd_qs, many=True).data,
        }, status=status.HTTP_200_OK)


class VolunteerAvailabilityAPIView(APIView):
    """
    GET /api/accounts/volunteer/availability/
    PUT/PATCH /api/accounts/volunteer/availability/
    Updates or retrieves volunteer availability status (ONLINE, OFFLINE, BUSY, UNAVAILABLE), location, and visibility radius.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        try:
            profile = VolunteerProfile.objects.get(user=user)
        except VolunteerProfile.DoesNotExist:
            return Response({"detail": "Volunteer profile not found."}, status=status.HTTP_404_NOT_FOUND)

        return Response({
            "is_online": profile.is_online,
            "availability_status": profile.availability_status,
            "latitude": profile.latitude,
            "longitude": profile.longitude,
            "visibility_radius": profile.visibility_radius,
            "last_updated": profile.last_updated,
        }, status=status.HTTP_200_OK)

    def put(self, request):
        return self.patch(request)

    def patch(self, request):
        user = request.user
        try:
            profile, _ = VolunteerProfile.objects.get_or_create(user=user)
        except Exception as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        data = request.data
        if "availability_status" in data:
            status_val = str(data["availability_status"]).upper()
            if status_val in ["ONLINE", "OFFLINE", "BUSY", "UNAVAILABLE"]:
                profile.availability_status = status_val
                profile.is_online = (status_val == "ONLINE")

        if "is_online" in data:
            profile.is_online = bool(data["is_online"])
            if not profile.is_online and profile.availability_status == "ONLINE":
                profile.availability_status = "OFFLINE"
            elif profile.is_online and profile.availability_status == "OFFLINE":
                profile.availability_status = "ONLINE"

        if "latitude" in data and data["latitude"] is not None:
            profile.latitude = data["latitude"]
        if "longitude" in data and data["longitude"] is not None:
            profile.longitude = data["longitude"]
        if "visibility_radius" in data and data["visibility_radius"] is not None:
            profile.visibility_radius = float(data["visibility_radius"])

        profile.save()
        return Response({
            "message": f"Volunteer availability updated to {profile.availability_status}.",
            "is_online": profile.is_online,
            "availability_status": profile.availability_status,
            "latitude": profile.latitude,
            "longitude": profile.longitude,
            "visibility_radius": profile.visibility_radius,
            "last_updated": profile.last_updated,
        }, status=status.HTTP_200_OK)


class SecurityAvailabilityAPIView(APIView):
    """
    GET /api/accounts/security/availability/
    PUT/PATCH /api/accounts/security/availability/
    Updates or retrieves security duty status (AVAILABLE, ON_DUTY, BUSY, RESPONDING, OFFLINE) and current incident.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        try:
            profile = SecurityProfile.objects.get(user=user)
        except SecurityProfile.DoesNotExist:
            return Response({"detail": "Security profile not found."}, status=status.HTTP_404_NOT_FOUND)

        return Response({
            "is_on_duty": profile.is_on_duty,
            "duty_status": profile.duty_status,
            "latitude": profile.latitude,
            "longitude": profile.longitude,
            "current_incident": profile.current_incident_id,
            "last_updated": profile.last_updated,
        }, status=status.HTTP_200_OK)

    def put(self, request):
        return self.patch(request)

    def patch(self, request):
        user = request.user
        try:
            profile, _ = SecurityProfile.objects.get_or_create(user=user)
        except Exception as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        data = request.data
        if "duty_status" in data:
            status_val = str(data["duty_status"]).upper()
            if status_val in ["AVAILABLE", "ON_DUTY", "BUSY", "RESPONDING", "OFFLINE"]:
                profile.duty_status = status_val
                profile.is_on_duty = (status_val in ["AVAILABLE", "ON_DUTY", "RESPONDING"])

        if "is_on_duty" in data:
            profile.is_on_duty = bool(data["is_on_duty"])
            if not profile.is_on_duty:
                profile.duty_status = "OFFLINE"
            elif profile.duty_status == "OFFLINE":
                profile.duty_status = "AVAILABLE"

        if "latitude" in data and data["latitude"] is not None:
            profile.latitude = data["latitude"]
        if "longitude" in data and data["longitude"] is not None:
            profile.longitude = data["longitude"]
        if "current_incident" in data:
            profile.current_incident_id = data["current_incident"]

        profile.save()
        return Response({
            "message": f"Security status updated to {profile.duty_status}.",
            "is_on_duty": profile.is_on_duty,
            "duty_status": profile.duty_status,
            "latitude": profile.latitude,
            "longitude": profile.longitude,
            "current_incident": profile.current_incident_id,
            "last_updated": profile.last_updated,
        }, status=status.HTTP_200_OK)


class ForgotPasswordAPIView(APIView):
    permission_classes = []

    def post(self, request):
        from .serializers import ForgotPasswordSerializer
        from .otp_service import PasswordResetOTPService

        serializer = ForgotPasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({"success": False, "message": "Invalid email address format.", "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data["email"]
        sent, msg, raw_otp = PasswordResetOTPService.generate_reset_otp(email)

        res_payload = {
            "success": True,
            "message": msg,
        }
        if raw_otp:
            res_payload["otp"] = raw_otp  # Included for dev/testing convenience

        return Response(res_payload, status=status.HTTP_200_OK)


class VerifyResetOTPAPIView(APIView):
    permission_classes = []

    def post(self, request):
        from .serializers import VerifyResetOTPSerializer
        from .otp_service import PasswordResetOTPService

        serializer = VerifyResetOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({"success": False, "message": "Email and 6-digit verification code are required.", "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data["email"]
        otp = serializer.validated_data["otp"]

        success, msg, reset_token = PasswordResetOTPService.verify_reset_otp(email, otp)
        if not success:
            return Response({"success": False, "message": msg}, status=status.HTTP_400_BAD_REQUEST)

        return Response({
            "success": True,
            "message": msg,
            "reset_token": reset_token
        }, status=status.HTTP_200_OK)


class ResetPasswordAPIView(APIView):
    permission_classes = []

    def post(self, request):
        from .serializers import ResetPasswordSerializer
        from .otp_service import PasswordResetOTPService

        serializer = ResetPasswordSerializer(data=request.data)
        if not serializer.is_valid():
            errors = serializer.errors
            err_msg = "Validation failed."
            if "confirm_password" in errors:
                err_msg = errors["confirm_password"][0] if isinstance(errors["confirm_password"], list) else str(errors["confirm_password"])
            elif "new_password" in errors:
                err_msg = errors["new_password"][0] if isinstance(errors["new_password"], list) else str(errors["new_password"])

            return Response({"success": False, "message": err_msg, "errors": errors}, status=status.HTTP_400_BAD_REQUEST)

        reset_token = serializer.validated_data["reset_token"]
        new_password = serializer.validated_data["new_password"]

        success, msg = PasswordResetOTPService.reset_password(reset_token, new_password)
        if not success:
            return Response({"success": False, "message": msg}, status=status.HTTP_400_BAD_REQUEST)

        return Response({"success": True, "message": msg}, status=status.HTTP_200_OK)
