"""
URL configuration for careconnect project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/6.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView
from sos.views import (
    ReverseGeocodeAPIView,
    EscalationConfigAPIView,
    EscalationLogViewSet,
    IncidentEscalationDetailView,
    SOSAcceptAPIView,
    SOSRejectAPIView,
    SOSStatusTransitionAPIView,
    SOSClosureAPIView,
    SOSTimelineAPIView,
    SOSChatAPIView,
    IncidentResponseUpdateAPIView,
)
from sos.security_views import (
    SecurityDashboardSummaryAPIView,
    SecurityIncidentsListAPIView,
    SecurityIncidentResolutionAPIView,
    SecurityReportingSummaryAPIView,
)
from accounts.directory_views import ContactDirectoryAPIView
from accounts.views import SendOTPAPIView, VerifyOTPAPIView, ResendOTPAPIView, LogoutAPIView, ForgotPasswordAPIView, VerifyResetOTPAPIView, ResetPasswordAPIView, HealthCheckAPIView
from society.reports_views import ReportDownloadAPIView

from emergency.views import (
    GenerateGuardianCodeView,
    MyGuardianCodeView,
    RespondGuardianLinkView,
    LinkGuardianView,
    UnlinkGuardianView,
    ResidentGuardiansView,
    ChangePrimaryGuardianView,
    GuardianDashboardAPIView,
)


from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/health/", HealthCheckAPIView.as_view(), name="health_check"),

    # JWT auth
    path("api/token/",         TokenObtainPairView.as_view(),  name="token_obtain_pair"),
    path("api/token/refresh/", TokenRefreshView.as_view(),     name="token_refresh"),

    # OTP auth
    path("api/auth/send-otp/",        SendOTPAPIView.as_view(),       name="send_otp"),
    path("api/auth/verify-otp/",      VerifyOTPAPIView.as_view(),     name="verify_otp"),
    path("api/auth/resend-otp/",      ResendOTPAPIView.as_view(),     name="resend_otp"),
    path("api/auth/logout/",          LogoutAPIView.as_view(),        name="auth_logout"),
    path("api/auth/forgot-password/", ForgotPasswordAPIView.as_view(), name="auth-forgot-password"),
    path("api/auth/verify-reset-otp/", VerifyResetOTPAPIView.as_view(), name="auth-verify-reset-otp"),
    path("api/auth/reset-password/",  ResetPasswordAPIView.as_view(),  name="auth-reset-password"),

    # App routes
    path("api/accounts/",      include("accounts.urls")),
    path("api/society/reports/download/", ReportDownloadAPIView.as_view(), name="society-reports-download"),
    path("api/society/",       include("society.urls")),
    path("api/emergency/",     include("emergency.urls")),
    path("api/notifications/", include("notifications.urls")),
    path("api/sos/",           include("sos.urls")),
    path("api/geocode/reverse/", ReverseGeocodeAPIView.as_view(), name="geocode-reverse"),

    # Direct Escalation & Incident Routes (Day 11 API specifications)
    path("api/escalation/config", EscalationConfigAPIView.as_view(), name="direct-escalation-config"),
    path("api/escalation/config/", EscalationConfigAPIView.as_view(), name="direct-escalation-config-slash"),
    path("api/escalation/logs", EscalationLogViewSet.as_view({'get': 'list'}), name="direct-escalation-logs"),
    path("api/escalation/logs/", EscalationLogViewSet.as_view({'get': 'list'}), name="direct-escalation-logs-slash"),
    path("api/incident/<int:pk>/escalation", IncidentEscalationDetailView.as_view(), name="direct-incident-escalation"),
    path("api/incident/<int:pk>/escalation/", IncidentEscalationDetailView.as_view(), name="direct-incident-escalation-slash"),
    path("api/incident/<int:pk>/accept", SOSAcceptAPIView.as_view(), name="direct-incident-accept"),
    path("api/incident/<int:pk>/accept/", SOSAcceptAPIView.as_view(), name="direct-incident-accept-slash"),
    path("api/incident/<int:pk>/reject", SOSRejectAPIView.as_view(), name="direct-incident-reject"),
    path("api/incident/<int:pk>/reject/", SOSRejectAPIView.as_view(), name="direct-incident-reject-slash"),
    path("api/incident/<int:pk>/status", SOSStatusTransitionAPIView.as_view(), name="direct-incident-status"),
    path("api/incident/<int:pk>/status/", SOSStatusTransitionAPIView.as_view(), name="direct-incident-status-slash"),
    path("api/incident/<int:pk>/closure", SOSClosureAPIView.as_view(), name="direct-incident-closure"),
    path("api/incident/<int:pk>/closure/", SOSClosureAPIView.as_view(), name="direct-incident-closure-slash"),
    path("api/incident/<int:pk>/timeline", SOSTimelineAPIView.as_view(), name="direct-incident-timeline"),
    path("api/incident/<int:pk>/timeline/", SOSTimelineAPIView.as_view(), name="direct-incident-timeline-slash"),
    path("api/incident/<int:pk>/chat", SOSChatAPIView.as_view(), name="direct-incident-chat"),
    path("api/incident/<int:pk>/chat/", SOSChatAPIView.as_view(), name="direct-incident-chat-slash"),
    path("api/directory/", ContactDirectoryAPIView.as_view(), name="direct-contact-directory"),
    path("api/incident/<int:pk>/updates", IncidentResponseUpdateAPIView.as_view(), name="direct-incident-updates"),
    path("api/incident/<int:pk>/updates/", IncidentResponseUpdateAPIView.as_view(), name="direct-incident-updates-slash"),
    path("api/security/dashboard/", SecurityDashboardSummaryAPIView.as_view(), name="direct-security-dashboard"),
    path("api/security/incidents/", SecurityIncidentsListAPIView.as_view(), name="direct-security-incidents"),
    path("api/security/incidents/<int:pk>/resolution/", SecurityIncidentResolutionAPIView.as_view(), name="direct-security-incident-resolution"),
    path("api/security/reports/summary/", SecurityReportingSummaryAPIView.as_view(), name="direct-security-reports-summary"),
    path("api/reports/download/", ReportDownloadAPIView.as_view(), name="direct-report-download"),
    path("api/reports/download", ReportDownloadAPIView.as_view(), name="direct-report-download-noslash"),

    # Direct Guardian & Resident Code Linking APIs
    path("api/guardian/dashboard/", GuardianDashboardAPIView.as_view(), name="guardian-dashboard"),
    path("api/emergency/guardians/dashboard/", GuardianDashboardAPIView.as_view(), name="emergency-guardian-dashboard"),
    path("api/guardian/generate-code/", GenerateGuardianCodeView.as_view(), name="guardian-generate-code"),
    path("api/guardian/my-code/", MyGuardianCodeView.as_view(), name="guardian-my-code"),
    path("api/guardian/respond-link/", RespondGuardianLinkView.as_view(), name="guardian-respond-link"),
    path("api/resident/link-guardian/", LinkGuardianView.as_view(), name="resident-link-guardian"),
    path("api/resident/unlink-guardian/", UnlinkGuardianView.as_view(), name="resident-unlink-guardian"),
    path("api/resident/unlink-guardian/<int:pk>/", UnlinkGuardianView.as_view(), name="resident-unlink-guardian-pk"),
    path("api/resident/guardians/", ResidentGuardiansView.as_view(), name="resident-guardians"),
    path("api/resident/change-primary/", ChangePrimaryGuardianView.as_view(), name="resident-change-primary"),


    # API Documentation & Swagger UI
    path("api/schema/",        SpectacularAPIView.as_view(),        name="schema"),
    path("api/docs/swagger/",  SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
    path("api/docs/redoc/",    SpectacularRedocView.as_view(url_name="schema"),   name="redoc"),
    path("swagger/",           SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-alias"),
    path("redoc/",             SpectacularRedocView.as_view(url_name="schema"),   name="redoc-alias"),
    path("docs/",              SpectacularSwaggerView.as_view(url_name="schema"), name="docs-alias"),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)


