"""
sos/views.py

Production-quality views for the SOS module.

Endpoints (all prefixed /api/sos/):
  GET    /categories/          — list active emergency categories
  GET    /incidents/           — list incidents (role-scoped)
  GET    /incidents/{id}/      — retrieve one incident
  GET    /history/             — authenticated resident's own history
  POST   /send/                — create new SOS incident
  PATCH  /accept/{id}/         — move Pending → Accepted
  PATCH  /in-progress/{id}/    — move Accepted → In Progress
  PATCH  /resolve/{id}/        — move In Progress → Resolved
  PATCH  /cancel/{id}/         — move any non-terminal → Cancelled

Search  : ?search=<term>   (resident name, email, category, status, message)
Filter  : ?status=Pending&category=1&resident=2&created_after=2024-01-01
Ordering: ?ordering=-created_at
Paginate: page_size=10 (via global DRF settings)
"""

from decimal import Decimal
from rest_framework import generics, permissions, filters, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django_filters.rest_framework import DjangoFilterBackend
from drf_spectacular.utils import extend_schema, OpenApiParameter

from .models import EmergencyCategory, SOSIncident, SOSEmergencyMessage
from .serializers import (
    EmergencyCategorySerializer,
    SOSIncidentSerializer,
    SOSSendSerializer,
    SOSStatusUpdateSerializer,
    SOSIncidentUpdateSerializer,
    SOSEmergencyMessageSerializer,
    SOSIncidentMessageUploadSerializer,
)

from .filters import SOSIncidentFilter
from .permissions import (
    CanViewSOS,
    IsSocietyManagerOrAdmin,
    IsSecurityRole,
    ROLE_ADMIN,
    ROLE_SOCIETY_MANAGER,
    ROLE_SECURITY,
    ROLE_VOLUNTEER,
)
from .services import SOSService


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_scoped_queryset(user):
    """Return incidents visible to *user* based on their role."""
    qs = SOSIncident.objects.select_related("resident", "category")
    if user.role in (ROLE_ADMIN, ROLE_SOCIETY_MANAGER, ROLE_SECURITY, "STAFF", "VOLUNTEER", "GUARDIAN"):
        return qs.all()
    # Residents list only their own incidents
    return qs.filter(resident=user)



# ---------------------------------------------------------------------------
# Category listing
# ---------------------------------------------------------------------------

@extend_schema(tags=["SOS — Categories"])
class EmergencyCategoryListView(generics.ListAPIView):
    """
    GET /api/sos/categories/
    Returns all active emergency categories.
    """
    queryset = EmergencyCategory.objects.filter(is_active=True).order_by("name")
    serializer_class = EmergencyCategorySerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [filters.SearchFilter]
    search_fields = ["name", "description"]


# ---------------------------------------------------------------------------
# Incident list / detail (read-only, role-scoped)
# ---------------------------------------------------------------------------

@extend_schema(
    tags=["SOS — Incidents"],
    parameters=[
        OpenApiParameter("search", str, description="Search by resident name/email, category, status, message"),
        OpenApiParameter("status", str, description="Filter by status"),
        OpenApiParameter("category", int, description="Filter by category ID"),
        OpenApiParameter("resident", int, description="Filter by resident ID"),
        OpenApiParameter("created_after", str, description="Date filter YYYY-MM-DD"),
        OpenApiParameter("created_before", str, description="Date filter YYYY-MM-DD"),
        OpenApiParameter("ordering", str, description="-created_at | updated_at | status"),
    ],
)
class SOSIncidentListView(generics.ListAPIView):
    """
    GET /api/sos/incidents/
    Lists SOS incidents scoped by the caller's role.
    Supports search, filter, ordering, and pagination.
    """
    serializer_class = SOSIncidentSerializer
    permission_classes = [permissions.IsAuthenticated, CanViewSOS]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = SOSIncidentFilter
    search_fields = [
        "resident__full_name",
        "resident__email",
        "category__name",
        "status",
        "message",
    ]
    ordering_fields = ["created_at", "updated_at", "status"]
    ordering = ["-created_at"]

    def get_queryset(self):
        # Guard against drf-spectacular schema introspection with AnonymousUser
        if getattr(self, "swagger_fake_view", False):
            return SOSIncident.objects.none()
        return _get_scoped_queryset(self.request.user)


@extend_schema(tags=["SOS — Incidents"])
class SOSIncidentDetailView(generics.RetrieveAPIView):
    """
    GET /api/sos/incidents/{id}/
    Retrieve a single SOS incident. Object-level permission enforced.
    """
    serializer_class = SOSIncidentSerializer
    permission_classes = [permissions.IsAuthenticated, CanViewSOS]

    def get_queryset(self):
        # Guard against drf-spectacular schema introspection with AnonymousUser
        if getattr(self, "swagger_fake_view", False):
            return SOSIncident.objects.none()
        return SOSIncident.objects.select_related("resident", "category").all()



# ---------------------------------------------------------------------------
# Resident history
# ---------------------------------------------------------------------------

@extend_schema(tags=["SOS — My History"])
class SOSHistoryView(generics.ListAPIView):
    """
    GET /api/sos/history/
    Returns the authenticated resident's own SOS history, newest first.
    Supports search, filter, and ordering.
    """
    serializer_class = SOSIncidentSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = SOSIncidentFilter
    search_fields = ["category__name", "status", "message"]
    ordering_fields = ["created_at", "updated_at", "status"]
    ordering = ["-created_at"]

    def get_queryset(self):
        # Guard against drf-spectacular schema introspection with AnonymousUser
        if getattr(self, "swagger_fake_view", False):
            return SOSIncident.objects.none()
        return (
            SOSIncident.objects
            .select_related("resident", "category")
            .filter(resident=self.request.user)
        )


# ---------------------------------------------------------------------------
# Send SOS (create)
# ---------------------------------------------------------------------------

@extend_schema(tags=["SOS — Actions"], request=SOSSendSerializer, responses={201: SOSIncidentSerializer})
class SOSSendView(generics.CreateAPIView):
    """
    POST /api/sos/send/
    Create a new SOS incident.
    - Automatically sets status = 'Pending'
    - Fires an 'Emergency Alert Received' notification
    """
    serializer_class = SOSSendSerializer
    permission_classes = [permissions.IsAuthenticated]

    def create(self, request, *args, **kwargs):
        print(f"[SOS DISPATCH REQUEST JSON] {request.data}", flush=True)
        serializer = self.get_serializer(data=request.data)
        print(f"[SOS SERIALIZER INITIAL DATA] {serializer.initial_data}", flush=True)
        if not serializer.is_valid():
            print(f"[SOS SERIALIZER ERRORS] {serializer.errors}", flush=True)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        incident = SOSService.create_incident(
            user=request.user,
            validated_data=serializer.validated_data,
        )

        response_data = SOSIncidentSerializer(incident, context={"request": request}).data
        return Response(response_data, status=status.HTTP_201_CREATED)




# ---------------------------------------------------------------------------
# Status-change actions (PATCH)
# ---------------------------------------------------------------------------

class _BaseStatusUpdateView(APIView):
    """
    Base class for status-change action views.
    Subclasses define `target_status` and `permission_classes`.
    """
    permission_classes = [permissions.IsAuthenticated]
    target_status: str = ""

    def patch(self, request, pk):
        # Validate optional note in body
        serializer = SOSStatusUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            incident = SOSIncident.objects.select_related("resident", "category").get(pk=pk)
        except SOSIncident.DoesNotExist:
            return Response(
                {"detail": "SOS incident not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Security and Volunteer may also update status
        user = request.user
        if user.role not in (ROLE_ADMIN, ROLE_SOCIETY_MANAGER, ROLE_SECURITY, ROLE_VOLUNTEER):
            return Response(
                {"detail": "You do not have permission to perform this action."},
                status=status.HTTP_403_FORBIDDEN,
            )

        try:
            updated = SOSService.update_status(incident, self.target_status, actor=user)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(
            SOSIncidentSerializer(updated, context={"request": request}).data,
            status=status.HTTP_200_OK,
        )


@extend_schema(tags=["SOS — Actions"], request=SOSStatusUpdateSerializer, responses={200: SOSIncidentSerializer})
class SOSAcceptView(_BaseStatusUpdateView):
    """PATCH /api/sos/accept/{id}/  →  Pending → Accepted"""
    target_status = "Accepted"


@extend_schema(tags=["SOS — Actions"], request=SOSStatusUpdateSerializer, responses={200: SOSIncidentSerializer})
class SOSInProgressView(_BaseStatusUpdateView):
    """PATCH /api/sos/in-progress/{id}/  →  Accepted → In Progress"""
    target_status = "In Progress"


@extend_schema(tags=["SOS — Actions"], request=SOSStatusUpdateSerializer, responses={200: SOSIncidentSerializer})
class SOSResolveView(_BaseStatusUpdateView):
    """PATCH /api/sos/resolve/{id}/  →  In Progress → Resolved"""
    target_status = "Resolved"


@extend_schema(tags=["SOS — Actions"], request=SOSStatusUpdateSerializer, responses={200: SOSIncidentSerializer})
class SOSCancelView(_BaseStatusUpdateView):
    """
    PATCH /api/sos/cancel/{id}/
    Residents can cancel their own incidents; managers/security/admin can cancel any.
    """
    target_status = "Cancelled"
    # Override permission — resident can cancel their own
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, pk):
        try:
            incident = SOSIncident.objects.select_related("resident", "category").get(pk=pk)
        except SOSIncident.DoesNotExist:
            return Response(
                {"detail": "SOS incident not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        user = request.user
        # Residents may only cancel their own
        if user.role == "RESIDENT" and incident.resident != user:
            return Response(
                {"detail": "You can only cancel your own SOS incidents."},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = SOSStatusUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            updated = SOSService.update_status(incident, "Cancelled", actor=user)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(
            SOSIncidentSerializer(updated, context={"request": request}).data,
            status=status.HTTP_200_OK,
        )


@extend_schema(tags=["SOS — Actions"], request=SOSIncidentUpdateSerializer, responses={200: SOSIncidentSerializer})
class SOSIncidentUpdateView(generics.UpdateAPIView):
    """
    PATCH /api/sos/{id}/
    Update message, priority, status, latitude, longitude, and address of an SOS incident.
    """
    queryset = SOSIncident.objects.all()
    serializer_class = SOSIncidentUpdateSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        obj = super().get_object()
        user = self.request.user
        # Residents can only update their own incidents
        if user.role == "RESIDENT" and obj.resident != user:
            raise permissions.exceptions.PermissionDenied(
                "You do not have permission to update this SOS incident."
            )
        return obj

    def perform_update(self, serializer):
        # Auto-reverse-geocode if coordinates are updated and address is not supplied
        latitude = serializer.validated_data.get("latitude")
        longitude = serializer.validated_data.get("longitude")
        address = serializer.validated_data.get("address")
        
        # If coordinates changed/supplied and no address provided, fetch it
        if address is None and (latitude is not None or longitude is not None):
            serializer.validated_data["address"] = SOSService.reverse_geocode(latitude, longitude)
            
        serializer.save()


@extend_schema(
    tags=["SOS — Messages"],
    request=SOSIncidentMessageUploadSerializer,
    responses={200: SOSIncidentSerializer}
)
class SOSEmergencyMessageCreateView(APIView):
    """
    POST /api/sos/{id}/message/
    Attach emergency text description and/or voice recording to an SOS incident.
    Accepts multipart/form-data, saves audio in MEDIA_ROOT, updates emergency_description,
    and returns the updated incident.
    """
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = (MultiPartParser, FormParser, JSONParser)

    def post(self, request, pk):
        try:
            incident = SOSIncident.objects.get(pk=pk)
        except SOSIncident.DoesNotExist:
            return Response(
                {"detail": "SOS incident not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        # Check access permission: residents can only add message to their own incident
        user = request.user
        if user.role == "RESIDENT" and incident.resident != user:
            return Response(
                {"detail": "You do not have permission to modify this incident."},
                status=status.HTTP_403_FORBIDDEN
            )

        serializer = SOSIncidentMessageUploadSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        validated_data = serializer.validated_data

        if "emergency_description" in validated_data:
            incident.emergency_description = validated_data["emergency_description"]
            if validated_data["emergency_description"].strip():
                incident.message = validated_data["emergency_description"]

        if "voice_message" in validated_data and validated_data["voice_message"]:
            incident.voice_message = validated_data["voice_message"]

        incident.save()

        # Also log message in SOSEmergencyMessage table if description provided
        if incident.emergency_description.strip():
            SOSEmergencyMessage.objects.create(
                incident=incident,
                sender=user,
                message=incident.emergency_description
            )

        return Response(
            SOSIncidentSerializer(incident, context={"request": request}).data,
            status=status.HTTP_200_OK
        )



@extend_schema(tags=["SOS — Messages"], responses={200: SOSEmergencyMessageSerializer(many=True)})
class SOSEmergencyMessageListView(generics.ListAPIView):
    """
    GET /api/sos/{id}/messages/
    Return all additional emergency text messages for an SOS incident.
    """
    serializer_class = SOSEmergencyMessageSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        incident_pk = self.kwargs.get("pk")
        try:
            incident = SOSIncident.objects.get(pk=incident_pk)
        except SOSIncident.DoesNotExist:
            return SOSEmergencyMessage.objects.none()

        # Check access permission
        user = self.request.user
        if user.role == "RESIDENT" and incident.resident != user:
            raise permissions.exceptions.PermissionDenied(
                "You do not have permission to view messages for this incident."
            )

        return SOSEmergencyMessage.objects.filter(incident=incident)


@extend_schema(
    tags=["Geocoding"],
    parameters=[
        OpenApiParameter("latitude", str, required=True, description="Latitude coordinate"),
        OpenApiParameter("longitude", str, required=True, description="Longitude coordinate"),
    ],
    responses={200: "application/json"}
)
class ReverseGeocodeAPIView(APIView):
    """
    GET /api/geocode/reverse/
    Parameters: latitude, longitude.
    Returns: address.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        latitude = request.query_params.get("latitude")
        longitude = request.query_params.get("longitude")
        if not latitude or not longitude:
            return Response(
                {"detail": "latitude and longitude parameters are required."},
                status=status.HTTP_400_BAD_REQUEST
            )
        try:
            lat_dec = Decimal(latitude)
            lon_dec = Decimal(longitude)
            if not (Decimal("-90") <= lat_dec <= Decimal("90")) or not (Decimal("-180") <= lon_dec <= Decimal("180")):
                return Response(
                    {"detail": "Invalid latitude/longitude range."},
                    status=status.HTTP_400_BAD_REQUEST
                )
        except Exception:
            return Response(
                {"detail": "Invalid coordinates formatting."},
                status=status.HTTP_400_BAD_REQUEST
            )

        address = SOSService.reverse_geocode(lat_dec, lon_dec)
        return Response({"address": address}, status=status.HTTP_200_OK)


from rest_framework import viewsets
from .models import EscalationConfig, EscalationLog
from .serializers import EscalationConfigSerializer, EscalationLogSerializer
import math

def haversine(lat1, lon1, lat2, lon2):
    # distance in meters
    R = 6371000  # radius of Earth in meters
    phi1 = math.radians(float(lat1))
    phi2 = math.radians(float(lat2))
    dphi = math.radians(float(lat2 - lat1))
    dlambda = math.radians(float(lon2 - lon1))
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c


class EscalationConfigViewSet(viewsets.ModelViewSet):
    queryset = EscalationConfig.objects.all()
    serializer_class = EscalationConfigSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Ensure a default config exists
        if not EscalationConfig.objects.exists():
            EscalationConfig.objects.create(
                id=1,
                response_time_minutes=5,
                response_time_window=30,
                escalation_enabled=True,
                notify_security=True,
                notify_volunteers=True,
                notify_admin=True
            )
        return EscalationConfig.objects.all()


class EscalationConfigAPIView(APIView):
    """
    GET  /escalation/config
    PUT  /escalation/config
    Single active configuration view.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        config, _ = EscalationConfig.objects.get_or_create(
            id=1,
            defaults={
                'response_time_minutes': 5,
                'response_time_window': 30,
                'escalation_enabled': True,
                'notify_security': True,
                'notify_volunteers': True,
                'notify_admin': True,
            }
        )
        serializer = EscalationConfigSerializer(config)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def put(self, request):
        config, _ = EscalationConfig.objects.get_or_create(id=1)
        serializer = EscalationConfigSerializer(config, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_200_OK)


class EscalationLogViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = EscalationLog.objects.all().order_by('-created_at')
    serializer_class = EscalationLogSerializer
    permission_classes = [permissions.IsAuthenticated]


class IncidentEscalationDetailView(APIView):
    """
    GET /incident/{id}/escalation
    Retrieve escalation tracking and logs for a specific SOS incident.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        try:
            incident = SOSIncident.objects.select_related('resident', 'category').get(pk=pk)
        except SOSIncident.DoesNotExist:
            return Response({"detail": "Incident not found."}, status=status.HTTP_404_NOT_FOUND)

        logs = EscalationLog.objects.filter(incident=incident).order_by('scheduled_at')
        logs_data = EscalationLogSerializer(logs, many=True).data

        current_log = logs.filter(status='TRIGGERED').last() or logs.first()
        current_level = current_log.step if current_log else 'Primary Guardian'
        current_assignee = current_log.new_recipient if current_log else 'Primary Guardian'

        return Response({
            "incident_id": incident.id,
            "resident_name": incident.resident.full_name,
            "status": incident.status,
            "current_escalation_level": current_level,
            "current_assignee": current_assignee,
            "escalation_history": logs_data,
        }, status=status.HTTP_200_OK)


class SOSAcceptAPIView(APIView):
    """
    POST /incident/{id}/accept
    Accept an SOS incident, stopping escalation.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            incident = SOSIncident.objects.select_related('resident', 'category').get(pk=pk)
        except SOSIncident.DoesNotExist:
            return Response({"detail": "SOS incident not found."}, status=status.HTTP_404_NOT_FOUND)

        if incident.status not in ["Pending", "Accepted"]:
            return Response(
                {"detail": f"Cannot accept incident in status '{incident.status}'."},
                status=status.HTTP_400_BAD_REQUEST
            )

        updated = SOSService.accept_incident(incident, actor=request.user)
        return Response(
            SOSIncidentSerializer(updated, context={"request": request}).data,
            status=status.HTTP_200_OK
        )


class SOSRejectAPIView(APIView):
    """
    POST /incident/{id}/reject
    Reject an SOS incident, recording rejection and triggering immediate escalation to the next step.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            incident = SOSIncident.objects.select_related('resident', 'category').get(pk=pk)
        except SOSIncident.DoesNotExist:
            return Response({"detail": "SOS incident not found."}, status=status.HTTP_404_NOT_FOUND)

        reason = request.data.get("reason", "")
        updated = SOSService.reject_incident(incident, actor=request.user, reason=reason)
        
        return Response({
            "detail": "SOS alert rejected. Escalated to next level immediately.",
            "incident": SOSIncidentSerializer(updated, context={"request": request}).data
        }, status=status.HTTP_200_OK)



class CommunityBroadcastAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            incident = SOSIncident.objects.select_related('resident').get(pk=pk)
        except SOSIncident.DoesNotExist:
            return Response({"detail": "Incident not found."}, status=status.HTTP_404_NOT_FOUND)

        if incident.latitude is None or incident.longitude is None:
            return Response({"detail": "Incident does not have valid coordinates to perform broadcast."}, status=status.HTTP_400_BAD_REQUEST)

        # Find online volunteers
        from accounts.models import VolunteerProfile
        volunteers = VolunteerProfile.objects.filter(is_online=True, latitude__isnull=False, longitude__isnull=False).select_related('user')
        
        notified_count = 0
        from notifications.services import NotificationEngineService
        for vol in volunteers:
            dist = haversine(incident.latitude, incident.longitude, vol.latitude, vol.longitude)
            if dist <= vol.visibility_radius:
                NotificationEngineService.dispatch_notification(
                    user=vol.user,
                    title="🚨 Nearby SOS Community Broadcast",
                    message=f"Urgent: {incident.resident.full_name} needs help nearby. Distance: {dist:.0f}m.",
                    category="sos",
                    incident=incident
                )
                notified_count += 1

        return Response({
            "message": "Broadcast sent successfully to nearby volunteers.",
            "volunteers_notified": notified_count
        }, status=status.HTTP_200_OK)


class IncidentTrackingStatsAPIView(APIView):
    permission_classes = []

    def get(self, request):
        from notifications.models import NotificationLog
        from accounts.models import VolunteerProfile, CustomUser
        from django.utils import timezone
        from datetime import timedelta
        
        # Get today's date range
        today_start = timezone.now().replace(hour=0, minute=0, second=0, microsecond=0)
        today_end = today_start + timedelta(days=1)
        
        # Incident counts
        total_incidents = SOSIncident.objects.count()
        pending = SOSIncident.objects.filter(status='Pending').count()
        accepted = SOSIncident.objects.filter(status='Accepted').count()
        in_progress = SOSIncident.objects.filter(status='In Progress').count()
        resolved = SOSIncident.objects.filter(status='Resolved').count()
        cancelled = SOSIncident.objects.filter(status='Cancelled').count()
        todays_incidents = SOSIncident.objects.filter(created_at__gte=today_start, created_at__lt=today_end).count()
        
        # Volunteer & Security counts
        volunteers_available = VolunteerProfile.objects.filter(is_online=True).count()
        security_online = CustomUser.objects.filter(role=ROLE_SECURITY, is_active=True).count()
        
        # Calculate delivery statistics
        total_delivery = NotificationLog.objects.count()
        successful_delivery = NotificationLog.objects.filter(status='SUCCESS').count()
        failed_delivery = NotificationLog.objects.filter(status='FAILURE').count()
        
        # Average response time
        accepted_incidents = SOSIncident.objects.filter(status__in=['Accepted', 'In Progress', 'Resolved'])
        total_seconds = 0
        count = 0
        for inc in accepted_incidents:
            diff = inc.updated_at - inc.created_at
            total_seconds += diff.total_seconds()
            count += 1
            
        avg_response_time = (total_seconds / count) if count > 0 else 0
        
        return Response({
            "total_incidents": total_incidents,
            "status_counts": {
                "Pending": pending,
                "Accepted": accepted,
                "In Progress": in_progress,
                "Resolved": resolved,
                "Cancelled": cancelled
            },
            "todays_incidents": todays_incidents,
            "volunteers_available": volunteers_available,
            "security_online": security_online,
            "delivery_stats": {
                "total": total_delivery,
                "success": successful_delivery,
                "failure": failed_delivery,
                "success_rate": (successful_delivery / total_delivery * 100) if total_delivery > 0 else 100
            },
            "average_response_time_seconds": avg_response_time,
            "guardian_response_metrics": {
                "total_escalated": EscalationLog.objects.filter(step='Secondary Guardian', status='TRIGGERED').count(),
                "escalation_rate": (EscalationLog.objects.filter(step='Secondary Guardian', status='TRIGGERED').count() / total_incidents * 100) if total_incidents > 0 else 0
            }
        })