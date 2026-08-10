"""
sos/urls.py

URL configuration for the SOS module.

All routes are prefixed with /api/sos/ (configured in careconnect/urls.py).

  GET    categories/          — list active emergency categories
  GET    incidents/           — list incidents (role-scoped, search/filter/order)
  GET    incidents/<id>/      — retrieve single incident
  GET    history/             — authenticated resident's own history
  POST   send/                — create new SOS incident
  PATCH  accept/<id>/         — Pending → Accepted
  PATCH  in-progress/<id>/    — Accepted → In Progress
  PATCH  resolve/<id>/        — In Progress → Resolved
  PATCH  cancel/<id>/         — any non-terminal → Cancelled
"""

from django.urls import path
from .views import (
    EmergencyCategoryListView,
    SOSIncidentListView,
    SOSIncidentDetailView,
    SOSHistoryView,
    SOSSendView,
    SOSAcceptView,
    SOSInProgressView,
    SOSResolveView,
    SOSCancelView,
    SOSIncidentUpdateView,
    SOSEmergencyMessageCreateView,
    SOSEmergencyMessageListView,
    SOSVoiceDeleteView,
    EscalationConfigViewSet,
    EscalationConfigAPIView,
    EscalationLogViewSet,
    IncidentEscalationDetailView,
    SOSAcceptAPIView,
    SOSRejectAPIView,
    CommunityBroadcastAPIView,
    BroadcastLogViewSet,
    BroadcastHistoryAPIView,
    IncidentTrackingStatsAPIView,
    AssignmentLogViewSet,
    SOSStatusTransitionAPIView,
    SOSClosureAPIView,
    SOSTimelineAPIView,
    IncidentStatusLogViewSet,
    SOSChatAPIView,
    SOSChatMessageDetailAPIView,
    IncidentResponseUpdateAPIView,
)
from .analytics_views import (
    DashboardSummaryAPIView,
    AlertStatusTrackingAPIView,
    NotificationDeliveryTrackingAPIView,
    ResponseMonitoringAPIView,
)
from .security_views import (
    SecurityDashboardSummaryAPIView,
    SecurityIncidentsListAPIView,
    SecurityIncidentStatusAPIView,
    SecurityIncidentResolutionAPIView,
    SecurityReportingSummaryAPIView,
)

urlpatterns = [
    # ── Day 13 Analytics & Dashboard Aggregation Routes ─────────────────────
    path("dashboard/summary/", DashboardSummaryAPIView.as_view(), name="sos-dashboard-summary"),
    path("analytics/dashboard-summary/", DashboardSummaryAPIView.as_view(), name="sos-analytics-dashboard-summary"),
    path("alert-status-tracking/", AlertStatusTrackingAPIView.as_view(), name="sos-alert-status-tracking"),
    path("incidents/<int:pk>/status-tracking/", AlertStatusTrackingAPIView.as_view(), name="sos-incident-status-tracking"),
    path("analytics/notification-delivery/", NotificationDeliveryTrackingAPIView.as_view(), name="sos-notification-delivery-tracking"),
    path("analytics/response-monitoring/", ResponseMonitoringAPIView.as_view(), name="sos-response-monitoring"),
    # ── Categories ──────────────────────────────────────────────────────────
    path("categories/", EmergencyCategoryListView.as_view(), name="sos-categories"),

    # ── Incidents (list + detail) ────────────────────────────────────────────
    path("incidents/",         SOSIncidentListView.as_view(),   name="sos-incident-list"),
    path("incidents/<int:pk>/", SOSIncidentDetailView.as_view(), name="sos-incident-detail"),
    path("incidents/tracking-stats/", IncidentTrackingStatsAPIView.as_view(), name="sos-incident-stats"),
    path("broadcast/", CommunityBroadcastAPIView.as_view(), name="sos-community-broadcast"),
    path("broadcast/logs/", BroadcastLogViewSet.as_view({'get': 'list'}), name="sos-broadcast-logs"),
    path("broadcast/history/", BroadcastHistoryAPIView.as_view(), name="sos-broadcast-history"),
    path("incidents/<int:pk>/broadcast/", CommunityBroadcastAPIView.as_view(), name="sos-incident-broadcast"),
    path("incidents/<int:pk>/escalation/", IncidentEscalationDetailView.as_view(), name="sos-incident-escalation"),
    path("incidents/<int:pk>/accept/", SOSAcceptAPIView.as_view(), name="sos-incident-accept-post"),
    path("incidents/<int:pk>/reject/", SOSRejectAPIView.as_view(), name="sos-incident-reject"),
    path("incidents/<int:pk>/assignment-logs/", AssignmentLogViewSet.as_view({'get': 'list'}), name="sos-incident-assignment-logs"),

    # ── Day 15 Lifecycle & Closure Routes ───────────────────────────────────
    path("incidents/<int:pk>/status/", SOSStatusTransitionAPIView.as_view(), name="sos-status-transition"),
    path("incidents/<int:pk>/closure/", SOSClosureAPIView.as_view(), name="sos-closure"),
    path("incidents/<int:pk>/timeline/", SOSTimelineAPIView.as_view(), name="sos-timeline"),
    path("incidents/<int:pk>/status-logs/", IncidentStatusLogViewSet.as_view({'get': 'list'}), name="sos-incident-status-logs"),
    path("status-logs/", IncidentStatusLogViewSet.as_view({'get': 'list'}), name="sos-status-logs"),

    # ── Day 16 Real-Time Emergency Chat Routes ─────────────────────────────
    path("incidents/<int:pk>/chat/", SOSChatAPIView.as_view(), name="sos-chat"),
    path("incidents/<int:pk>/chat/<int:message_id>/", SOSChatMessageDetailAPIView.as_view(), name="sos-chat-detail"),

    # ── Day 17 Incident Response Updates Feed Routes ───────────────────────
    path("incidents/<int:pk>/updates/", IncidentResponseUpdateAPIView.as_view(), name="sos-updates"),

    # ── Day 18 Security Operations Dashboard Routes ────────────────────────
    path("security/dashboard/", SecurityDashboardSummaryAPIView.as_view(), name="security-dashboard-summary"),
    path("security/incidents/", SecurityIncidentsListAPIView.as_view(), name="security-incidents-list"),
    path("security/incidents/<int:pk>/status/", SecurityIncidentStatusAPIView.as_view(), name="security-incident-status"),
    path("security/incidents/<int:pk>/resolution/", SecurityIncidentResolutionAPIView.as_view(), name="security-incident-resolution"),
    path("security/reports/summary/", SecurityReportingSummaryAPIView.as_view(), name="security-reports-summary"),

    # ── My History ──────────────────────────────────────────────────────────
    path("history/", SOSHistoryView.as_view(), name="sos-history"),

    # ── Send (create) ───────────────────────────────────────────────────────
    path("send/", SOSSendView.as_view(), name="sos-send"),

    # ── Status-change actions ────────────────────────────────────────────────
    path("accept/<int:pk>/",      SOSAcceptView.as_view(),     name="sos-accept"),
    path("in-progress/<int:pk>/", SOSInProgressView.as_view(), name="sos-in-progress"),
    path("incidents/<int:pk>/in-progress/", SOSInProgressView.as_view(), name="sos-incident-in-progress"),
    path("resolve/<int:pk>/",     SOSResolveView.as_view(),    name="sos-resolve"),
    path("incidents/<int:pk>/resolve/", SOSResolveView.as_view(), name="sos-incident-resolve"),
    path("cancel/<int:pk>/",      SOSCancelView.as_view(),     name="sos-cancel"),
    path("incidents/<int:pk>/cancel/", SOSCancelView.as_view(),   name="sos-incident-cancel"),

    # ── Update & Emergency Messages ──────────────────────────────────────────
    path("<int:pk>/",             SOSIncidentUpdateView.as_view(),    name="sos-update"),
    path("<int:pk>/message/",     SOSEmergencyMessageCreateView.as_view(), name="sos-message-create"),
    path("incidents/<int:pk>/message/", SOSEmergencyMessageCreateView.as_view(), name="sos-incident-message-create"),
    path("<int:pk>/messages/",    SOSEmergencyMessageListView.as_view(),   name="sos-message-list"),
    path("incidents/<int:pk>/messages/", SOSEmergencyMessageListView.as_view(), name="sos-incident-message-list"),
    path("<int:pk>/voice/",       SOSVoiceDeleteView.as_view(),            name="sos-voice-delete"),
    path("incidents/<int:pk>/voice/", SOSVoiceDeleteView.as_view(),       name="sos-incident-voice-delete"),

    # ── Escalation Settings & Logs ───────────────────────────────────────────
    path("escalation-config/", EscalationConfigViewSet.as_view({'get': 'list', 'post': 'create'}), name="escalation-config-list"),
    path("escalation-config/<int:pk>/", EscalationConfigViewSet.as_view({'get': 'retrieve', 'put': 'update', 'patch': 'partial_update', 'delete': 'destroy'}), name="escalation-config-detail"),
    path("escalation/config", EscalationConfigAPIView.as_view(), name="escalation-config-api"),
    path("escalation/logs", EscalationLogViewSet.as_view({'get': 'list'}), name="escalation-logs-api"),
    path("escalation-logs/", EscalationLogViewSet.as_view({'get': 'list'}), name="escalation-logs-list"),
    path("escalation-logs/<int:pk>/", EscalationLogViewSet.as_view({'get': 'retrieve'}), name="escalation-logs-detail"),
    path("assignment-logs/", AssignmentLogViewSet.as_view({'get': 'list'}), name="assignment-logs-list"),
]