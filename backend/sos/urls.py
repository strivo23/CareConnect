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
    EscalationConfigViewSet,
    EscalationConfigAPIView,
    EscalationLogViewSet,
    IncidentEscalationDetailView,
    SOSAcceptAPIView,
    SOSRejectAPIView,
    CommunityBroadcastAPIView,
    IncidentTrackingStatsAPIView,
)

urlpatterns = [
    # ── Categories ──────────────────────────────────────────────────────────
    path("categories/", EmergencyCategoryListView.as_view(), name="sos-categories"),

    # ── Incidents (list + detail) ────────────────────────────────────────────
    path("incidents/",         SOSIncidentListView.as_view(),   name="sos-incident-list"),
    path("incidents/<int:pk>/", SOSIncidentDetailView.as_view(), name="sos-incident-detail"),
    path("incidents/tracking-stats/", IncidentTrackingStatsAPIView.as_view(), name="sos-incident-stats"),
    path("incidents/<int:pk>/broadcast/", CommunityBroadcastAPIView.as_view(), name="sos-incident-broadcast"),
    path("incidents/<int:pk>/escalation/", IncidentEscalationDetailView.as_view(), name="sos-incident-escalation"),
    path("incidents/<int:pk>/accept/", SOSAcceptAPIView.as_view(), name="sos-incident-accept-post"),
    path("incidents/<int:pk>/reject/", SOSRejectAPIView.as_view(), name="sos-incident-reject"),

    # ── My History ──────────────────────────────────────────────────────────
    path("history/", SOSHistoryView.as_view(), name="sos-history"),

    # ── Send (create) ───────────────────────────────────────────────────────
    path("send/", SOSSendView.as_view(), name="sos-send"),

    # ── Status-change actions ────────────────────────────────────────────────
    path("accept/<int:pk>/",      SOSAcceptView.as_view(),     name="sos-accept"),
    path("in-progress/<int:pk>/", SOSInProgressView.as_view(), name="sos-in-progress"),
    path("resolve/<int:pk>/",     SOSResolveView.as_view(),    name="sos-resolve"),
    path("cancel/<int:pk>/",      SOSCancelView.as_view(),     name="sos-cancel"),

    # ── Update & Emergency Messages ──────────────────────────────────────────
    path("<int:pk>/",             SOSIncidentUpdateView.as_view(),    name="sos-update"),
    path("<int:pk>/message/",     SOSEmergencyMessageCreateView.as_view(), name="sos-message-create"),
    path("<int:pk>/messages/",    SOSEmergencyMessageListView.as_view(),   name="sos-message-list"),

    # ── Escalation Settings & Logs ───────────────────────────────────────────
    path("escalation-config/", EscalationConfigViewSet.as_view({'get': 'list', 'post': 'create'}), name="escalation-config-list"),
    path("escalation-config/<int:pk>/", EscalationConfigViewSet.as_view({'get': 'retrieve', 'put': 'update', 'patch': 'partial_update', 'delete': 'destroy'}), name="escalation-config-detail"),
    path("escalation/config", EscalationConfigAPIView.as_view(), name="escalation-config-api"),
    path("escalation/logs", EscalationLogViewSet.as_view({'get': 'list'}), name="escalation-logs-api"),
    path("escalation-logs/", EscalationLogViewSet.as_view({'get': 'list'}), name="escalation-logs-list"),
    path("escalation-logs/<int:pk>/", EscalationLogViewSet.as_view({'get': 'retrieve'}), name="escalation-logs-detail"),
]