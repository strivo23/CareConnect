from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    RegisterAPIView,
    LoginAPIView,
    LogoutAPIView,
    ResidentProfileViewSet,
    VolunteerProfileViewSet,
    SecurityProfileViewSet,
    GuardianProfileViewSet,
    UserDocumentViewSet,
    VerificationCenterAPIView,
    DashboardStatsAPIView,
    MeAPIView,
    CreateSuperuserAPIView,
    SendSuperuserOTPAPIView,
    VolunteerAvailabilityAPIView,
    SecurityAvailabilityAPIView,
    ForgotPasswordAPIView,
    VerifyResetOTPAPIView,
    ResetPasswordAPIView,
    HealthCheckAPIView
)

router = DefaultRouter()
router.register('residents', ResidentProfileViewSet, basename='resident')
router.register('volunteers', VolunteerProfileViewSet, basename='volunteer')
router.register('security', SecurityProfileViewSet, basename='security')
router.register('guardians', GuardianProfileViewSet, basename='guardian')
router.register('documents', UserDocumentViewSet, basename='document')

urlpatterns = [
    path("health/", HealthCheckAPIView.as_view(), name="health_check"),
    path("register/", RegisterAPIView.as_view(), name="register"),
    path("login/", LoginAPIView.as_view(), name="login"),
    path("logout/", LogoutAPIView.as_view(), name="logout"),
    path("forgot-password/", ForgotPasswordAPIView.as_view(), name="forgot_password"),
    path("verify-reset-otp/", VerifyResetOTPAPIView.as_view(), name="verify_reset_otp"),
    path("reset-password/", ResetPasswordAPIView.as_view(), name="reset_password"),
    path("send-superuser-otp/", SendSuperuserOTPAPIView.as_view(), name="send_superuser_otp"),
    path("create-superuser/", CreateSuperuserAPIView.as_view(), name="create_superuser"),
    path("me/", MeAPIView.as_view(), name="me"),
    path("volunteer/availability/", VolunteerAvailabilityAPIView.as_view(), name="volunteer_availability"),
    path("security/availability/", SecurityAvailabilityAPIView.as_view(), name="security_availability"),
    path("verification-center/", VerificationCenterAPIView.as_view(), name="verification_center"),
    path("dashboard-stats/", DashboardStatsAPIView.as_view(), name="dashboard_stats"),
    path("", include(router.urls)),
]