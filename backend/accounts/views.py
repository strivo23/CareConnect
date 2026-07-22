from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, viewsets, filters
from rest_framework.decorators import action
from django.contrib.auth import authenticate
from django.utils import timezone
from rest_framework_simplejwt.tokens import RefreshToken

from .serializers import RegisterSerializer, LoginSerializer, ResidentProfileSerializer, UserSerializer
from .models import ResidentProfile

class RegisterAPIView(APIView):
    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            
            # Generate registration OTP
            import random
            from django.utils import timezone
            from .models import OTPVerification
            otp = str(random.randint(100000, 999999))
            expires_at = timezone.now() + timezone.timedelta(minutes=10)
            OTPVerification.objects.create(
                user=user,
                otp=otp,
                expires_at=expires_at
            )
            print(f"[MOCK OTP] Sent registration OTP {otp} to {user.email}", flush=True)

            
            res_data = serializer.data
            res_data["otp"] = otp  # Include OTP in response for testing/development flow convenience
            return Response(res_data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LoginAPIView(APIView):
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if serializer.is_valid():
            email = serializer.validated_data["email"]
            password = serializer.validated_data["password"]
            user = authenticate(email=email, password=password)
            if user:
                refresh = RefreshToken.for_user(user)
                return Response({
                    "message": "Login successful",
                    "refresh": str(refresh),
                    "access": str(refresh.access_token),
                    "user": UserSerializer(user).data
                    }, status=status.HTTP_200_OK)
            return Response({"message": "Invalid credentials"}, status=status.HTTP_401_UNAUTHORIZED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

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
    def post(self, request):
        email = request.data.get('email')
        if not email:
            return Response({"email": "Email is required."}, status=status.HTTP_400_BAD_REQUEST)
        
        from accounts.models import User
        user = User.objects.filter(email=email).first()
        if not user:
            return Response({"detail": "User not found."}, status=status.HTTP_444_NOT_FOUND)
        
        import random
        from django.utils import timezone
        from .models import OTPVerification
        
        otp = str(random.randint(100000, 999999))
        expires_at = timezone.now() + timezone.timedelta(minutes=10)
        OTPVerification.objects.create(
            user=user,
            otp=otp,
            expires_at=expires_at
        )
        
        print(f"[MOCK OTP] Sent OTP {otp} to {email}", flush=True)
        return Response({"message": "OTP sent successfully.", "otp": otp}, status=status.HTTP_200_OK)


class VerifyOTPAPIView(APIView):
    def post(self, request):
        email = request.data.get('email')
        otp = request.data.get('otp')
        if not email or not otp:
            return Response({"detail": "Email and OTP are required."}, status=status.HTTP_400_BAD_REQUEST)
        
        from accounts.models import User
        user = User.objects.filter(email=email).first()
        if not user:
            return Response({"detail": "User not found."}, status=status.HTTP_444_NOT_FOUND)
        
        from django.utils import timezone
        from .models import OTPVerification
        
        otp_record = OTPVerification.objects.filter(
            user=user, 
            is_verified=False,
            otp=otp
        ).order_by('-created_at').first()
        
        if not otp_record:
            return Response({"detail": "Invalid OTP."}, status=status.HTTP_400_BAD_REQUEST)
        
        if timezone.now() > otp_record.expires_at:
            return Response({"detail": "OTP has expired."}, status=status.HTTP_400_BAD_REQUEST)
        
        otp_record.is_verified = True
        otp_record.save()
        
        user.is_verified = True
        user.save()
        
        return Response({"message": "Verification successful.", "is_verified": True}, status=status.HTTP_200_OK)


class ResendOTPAPIView(APIView):
    def post(self, request):
        email = request.data.get('email')
        if not email:
            return Response({"email": "Email is required."}, status=status.HTTP_400_BAD_REQUEST)
        
        from accounts.models import User
        user = User.objects.filter(email=email).first()
        if not user:
            return Response({"detail": "User not found."}, status=status.HTTP_444_NOT_FOUND)
        
        import random
        from django.utils import timezone
        from .models import OTPVerification
        
        otp = str(random.randint(100000, 999999))
        expires_at = timezone.now() + timezone.timedelta(minutes=10)
        OTPVerification.objects.create(
            user=user,
            otp=otp,
            expires_at=expires_at
        )
        
        print(f"[MOCK OTP] Resent OTP {otp} to {email}", flush=True)
        return Response({"message": "OTP resent successfully.", "otp": otp}, status=status.HTTP_200_OK)