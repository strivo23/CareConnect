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

from .models import EmergencyCategory, SOSIncident, SOSEmergencyMessage, AssignmentLog, IncidentStatusLog, IncidentChatMessage, IncidentResponseUpdate
from .serializers import (
    EmergencyCategorySerializer,
    SOSIncidentSerializer,
    SOSSendSerializer,
    SOSStatusUpdateSerializer,
    SOSIncidentUpdateSerializer,
    SOSEmergencyMessageSerializer,
    SOSIncidentMessageUploadSerializer,
    AssignmentLogSerializer,
    IncidentStatusLogSerializer,
    IncidentChatMessageSerializer,
    IncidentResponseUpdateSerializer,
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
from .services import SOSService, AlreadyAssignedException, IncidentLifecycleService, IncidentChatService, IncidentResponseUpdateService



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
    - Fires 'Emergency Alert Received' notification
    """
    serializer_class = SOSSendSerializer
    permission_classes = [permissions.IsAuthenticated]

    def create(self, request, *args, **kwargs):
        print(f"[SOS DISPATCH REQUEST JSON] {request.data}", flush=True)
        serializer = self.get_serializer(data=request.data)
        if not serializer.is_valid():
            first_err = "Invalid SOS request data."
            if serializer.errors:
                first_key = list(serializer.errors.keys())[0]
                val = serializer.errors[first_key]
                first_err = f"{first_key}: {val[0]}" if isinstance(val, list) and val else str(val)
            print(f"[SOS SERIALIZER ERRORS] {serializer.errors}", flush=True)
            return Response({
                "success": False,
                "message": first_err,
                "detail": first_err,
                "errors": serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            incident = SOSService.create_incident(
                user=request.user,
                validated_data=serializer.validated_data,
            )
        except ValueError as val_err:
            errMsg = str(val_err)
            status_code = status.HTTP_409_CONFLICT if "already in progress" in errMsg else status.HTTP_400_BAD_REQUEST
            return Response({
                "success": False,
                "message": errMsg,
                "detail": errMsg
            }, status=status_code)
        except Exception as exc:
            errMsg = f"Failed to dispatch SOS: {str(exc)}"
            return Response({
                "success": False,
                "message": errMsg,
                "detail": errMsg
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        response_data = SOSIncidentSerializer(incident, context={"request": request}).data
        response_data["success"] = True
        response_data["notifications_summary"] = getattr(incident, "notifications_summary", {
            "guardian_notified": True,
            "security_notified": True,
            "volunteer_notified": True,
            "emergency_contacts_notified": True,
        })
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

        # Security, Volunteer, Admin, or Linked Guardian may update status
        user = request.user
        from emergency.models import ResidentGuardian
        is_linked_guardian = ResidentGuardian.objects.filter(guardian=user, resident=incident.resident, status='Active').exists()

        if user.role not in (ROLE_ADMIN, ROLE_SOCIETY_MANAGER, ROLE_SECURITY, ROLE_VOLUNTEER) and not is_linked_guardian:
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
        # Prevent editing after acceptance for residents
        if user.role == "RESIDENT" and obj.status in ["Accepted", "Assigned", "In Progress", "Resolved", "Cancelled"]:
            raise permissions.exceptions.PermissionDenied(
                "Emergency details cannot be modified after an incident has been accepted by a responder."
            )
        return obj

    def perform_update(self, serializer):
        # Auto-reverse-geocode if coordinates are updated and address is not supplied
        latitude = serializer.validated_data.get("latitude")
        longitude = serializer.validated_data.get("longitude")
        address = serializer.validated_data.get("address")
        
        if latitude is not None and longitude is not None:
            geo_details = SOSService.reverse_geocode_details(latitude, longitude)
            if not address or address in ["Address not resolved", "Address unavailable", "Location unavailable", ""]:
                serializer.validated_data["address"] = geo_details["address"]
            if not serializer.validated_data.get("city"):
                serializer.validated_data["city"] = geo_details["city"]
            if not serializer.validated_data.get("state"):
                serializer.validated_data["state"] = geo_details["state"]
            if not serializer.validated_data.get("country"):
                serializer.validated_data["country"] = geo_details["country"]
            if not serializer.validated_data.get("pincode"):
                serializer.validated_data["pincode"] = geo_details["pincode"]
            
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

        if user.role == "RESIDENT" and incident.status in ["Accepted", "Assigned", "In Progress", "Resolved", "Cancelled"]:
            return Response(
                {"detail": "Emergency message cannot be attached after an incident has been accepted by a responder."},
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = SOSIncidentMessageUploadSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        validated_data = serializer.validated_data

        if "emergency_description" in validated_data and validated_data["emergency_description"]:
            incident.emergency_description = validated_data["emergency_description"]
            if validated_data["emergency_description"].strip():
                incident.message = validated_data["emergency_description"]

        if "voice_message" in validated_data and validated_data["voice_message"]:
            incident.voice_message = validated_data["voice_message"]
            from django.utils import timezone
            incident.voice_uploaded_at = timezone.now()
            if "voice_duration" in validated_data and validated_data["voice_duration"]:
                incident.voice_duration = validated_data["voice_duration"]

        incident.save()

        # Also log message in SOSEmergencyMessage table if description provided
        if incident.emergency_description and incident.emergency_description.strip():
            SOSEmergencyMessage.objects.create(
                incident=incident,
                sender=user,
                message=incident.emergency_description
            )

        return Response(
            SOSIncidentSerializer(incident, context={"request": request}).data,
            status=status.HTTP_200_OK
        )


@extend_schema(tags=["SOS — Messages"], responses={200: SOSIncidentSerializer})
class SOSVoiceDeleteView(APIView):
    """
    DELETE /api/sos/{id}/voice/
    Delete voice recording attached to an SOS incident.
    """
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, pk):
        try:
            incident = SOSIncident.objects.get(pk=pk)
        except SOSIncident.DoesNotExist:
            return Response(
                {"detail": "SOS incident not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        user = request.user
        if user.role == "RESIDENT" and incident.resident != user:
            return Response(
                {"detail": "You do not have permission to modify this incident."},
                status=status.HTTP_403_FORBIDDEN
            )

        if user.role == "RESIDENT" and incident.status in ["Accepted", "Assigned", "In Progress", "Resolved", "Cancelled"]:
            return Response(
                {"detail": "Voice recording cannot be deleted after an incident has been accepted by a responder."},
                status=status.HTTP_400_BAD_REQUEST
            )

        incident.voice_message = None
        incident.voice_duration = None
        incident.voice_uploaded_at = None
        incident.save()

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
    Returns: address, city, state, country, pincode.
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

        res = SOSService.reverse_geocode_details(lat_dec, lon_dec)
        return Response(res, status=status.HTTP_200_OK)


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


def _get_client_ip(request):
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        return x_forwarded_for.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR')


class SOSAcceptAPIView(APIView):
    """
    POST /api/sos/incidents/{incident_id}/accept/
    Formally accept an SOS incident (Responder Assignment).
    Only authenticated users with Volunteer or Security roles may call this.
    Prevents race conditions & duplicate assignments with database transaction locks.
    Returns HTTP 409 Conflict if already assigned.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        user = request.user
        from emergency.models import ResidentGuardian

        try:
            incident_obj = SOSIncident.objects.get(pk=pk)
            is_linked_guardian = ResidentGuardian.objects.filter(guardian=user, resident=incident_obj.resident, status='Active').exists()
        except SOSIncident.DoesNotExist:
            return Response({"detail": "SOS incident not found."}, status=status.HTTP_404_NOT_FOUND)

        if user.role not in [ROLE_VOLUNTEER, ROLE_SECURITY] and not is_linked_guardian:
            return Response(
                {"detail": "Only authorized responders or linked guardians can accept incidents."},
                status=status.HTTP_403_FORBIDDEN
            )


        ip_address = _get_client_ip(request)

        try:
            incident = SOSService.accept_and_assign_incident(
                incident_id=pk,
                responder=user,
                ip_address=ip_address
            )
        except SOSIncident.DoesNotExist:
            return Response(
                {"detail": "SOS incident not found."},
                status=status.HTTP_404_NOT_FOUND
            )
        except AlreadyAssignedException:
            return Response(
                {
                    "success": False,
                    "detail": "This incident has already been assigned.",
                    "message": "This incident has already been assigned."
                },
                status=status.HTTP_409_CONFLICT
            )
        except ValueError as exc:
            return Response(
                {"detail": str(exc)},
                status=status.HTTP_400_BAD_REQUEST
            )

        incident_data = SOSIncidentSerializer(incident, context={"request": request}).data

        return Response(
            {
                "success": True,
                "incident": incident_data,
                "assigned_to": user.full_name or user.email,
                "accepted_at": incident.accepted_at.isoformat() if incident.accepted_at else None,
                "status": incident.status
            },
            status=status.HTTP_200_OK
        )


class AssignmentLogViewSet(viewsets.ReadOnlyModelViewSet):
    """
    GET /api/sos/assignment-logs/
    Audit trail listing responder assignments.
    """
    queryset = AssignmentLog.objects.all().order_by('-created_at')
    serializer_class = AssignmentLogSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = super().get_queryset()
        incident_id = self.kwargs.get('pk') or self.request.query_params.get('incident')
        if incident_id:
            qs = qs.filter(incident_id=incident_id)
        return qs


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


class SOSStatusTransitionAPIView(APIView):
    """
    POST /api/sos/incidents/{id}/status/
    Payload: {"status": "ACTIVE", "remarks": "..."}
    Validates state machine transitions & role permissions via IncidentLifecycleService.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        new_status = request.data.get("status")
        remarks = request.data.get("remarks")
        ip_address = _get_client_ip(request)

        if not new_status:
            return Response({"success": False, "message": "Field 'status' is required."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            incident = IncidentLifecycleService.transition_status(
                incident_id=pk,
                new_status=new_status,
                user=request.user,
                remarks=remarks,
                ip_address=ip_address
            )
            serializer = SOSIncidentSerializer(incident, context={"request": request})
            return Response({
                "success": True,
                "message": f"Incident status transitioned to '{new_status}'.",
                "incident": serializer.data
            }, status=status.HTTP_200_OK)
        except ValueError as exc:
            return Response({"success": False, "message": str(exc), "status": [str(exc)]}, status=status.HTTP_400_BAD_REQUEST)
        except PermissionError as exc:
            return Response({"success": False, "message": str(exc)}, status=status.HTTP_403_FORBIDDEN)
        except Exception as exc:
            return Response({"success": False, "message": f"Unexpected error: {str(exc)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class SOSClosureAPIView(APIView):
    """
    POST /api/sos/incidents/{id}/closure/
    Payload: {"resolution_summary": "...", "closure_notes": "...", "closure_reason": "..."}
    Closes a RESOLVED incident.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        resolution_summary = request.data.get("resolution_summary")
        closure_notes = request.data.get("closure_notes", "")
        closure_reason = request.data.get("closure_reason")
        attachments = request.data.get("attachments")
        ip_address = _get_client_ip(request)

        if not resolution_summary or not closure_reason:
            return Response({
                "success": False,
                "message": "Fields 'resolution_summary' and 'closure_reason' are required to close an incident."
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            incident = IncidentLifecycleService.close_incident(
                incident_id=pk,
                user=request.user,
                resolution_summary=resolution_summary,
                closure_notes=closure_notes,
                closure_reason=closure_reason,
                attachments=attachments,
                ip_address=ip_address
            )
            serializer = SOSIncidentSerializer(incident, context={"request": request})
            return Response({
                "success": True,
                "message": "Incident closed successfully with closure documentation.",
                "incident": serializer.data
            }, status=status.HTTP_200_OK)
        except ValueError as exc:
            return Response({"success": False, "message": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        except PermissionError as exc:
            return Response({"success": False, "message": str(exc)}, status=status.HTTP_403_FORBIDDEN)
        except Exception as exc:
            return Response({"success": False, "message": f"Unexpected error: {str(exc)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class SOSTimelineAPIView(APIView):
    """
    GET /api/sos/incidents/{id}/timeline/
    Returns full vertical lifecycle timeline from OPEN to CLOSED.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        timeline = IncidentLifecycleService.get_incident_timeline(incident_id=pk)
        return Response({
            "success": True,
            "incident_id": pk,
            "timeline": timeline
        }, status=status.HTTP_200_OK)


from rest_framework import viewsets

class IncidentStatusLogViewSet(viewsets.ReadOnlyModelViewSet):
    """
    GET /api/sos/status-logs/
    Audit trail for incident status changes.
    """
    queryset = IncidentStatusLog.objects.all().order_by('-timestamp')
    serializer_class = IncidentStatusLogSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = super().get_queryset()
        incident_id = self.kwargs.get('pk') or self.request.query_params.get('incident')
        if incident_id:
            qs = qs.filter(incident_id=incident_id)
        return qs


from rest_framework.pagination import PageNumberPagination

class SOSChatAPIView(APIView):
    """
    GET /api/sos/incidents/{id}/chat/
    Retrieve chat message history for an incident.

    POST /api/sos/incidents/{id}/chat/
    Send a message (text, image, voice, location, file, reply_to).
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        try:
            incident = SOSIncident.objects.select_related("resident", "assigned_responder").get(pk=pk)
        except SOSIncident.DoesNotExist:
            return Response({"error": "Incident not found."}, status=status.HTTP_404_NOT_FOUND)

        if not IncidentChatService.is_participant(incident, request.user):
            return Response({"error": "Only incident participants can view chat history."}, status=status.HTTP_403_FORBIDDEN)

        qs = IncidentChatMessage.objects.filter(incident=incident).select_related(
            "sender", "reply_to", "reply_to__sender"
        )

        sender_filter = request.query_params.get("sender")
        if sender_filter:
            qs = qs.filter(sender_id=sender_filter)

        msg_type_filter = request.query_params.get("message_type")
        if msg_type_filter:
            qs = qs.filter(message_type=msg_type_filter)

        search_query = request.query_params.get("search")
        if search_query:
            qs = qs.filter(message__icontains=search_query)

        ordering = request.query_params.get("ordering", "created_at")
        if ordering in ["created_at", "-created_at"]:
            qs = qs.order_by(ordering)
        else:
            qs = qs.order_by("created_at")

        paginator = PageNumberPagination()
        paginator.page_size = 50
        page = paginator.paginate_queryset(qs, request)
        if page is not None:
            serializer = IncidentChatMessageSerializer(page, many=True)
            return paginator.get_paginated_response(serializer.data)

        serializer = IncidentChatMessageSerializer(qs, many=True)
        return Response({
            "success": True,
            "incident_id": pk,
            "count": qs.count(),
            "results": serializer.data
        }, status=status.HTTP_200_OK)

    def post(self, request, pk):
        try:
            incident = SOSIncident.objects.select_related("resident", "assigned_responder").get(pk=pk)
        except SOSIncident.DoesNotExist:
            return Response({"error": "Incident not found."}, status=status.HTTP_404_NOT_FOUND)

        try:
            msg_text = request.data.get("message", "")
            msg_type = request.data.get("message_type", "TEXT")
            attachment = request.FILES.get("attachment")
            latitude = request.data.get("latitude")
            longitude = request.data.get("longitude")
            reply_to_id = request.data.get("reply_to")

            reply_to_obj = None
            if reply_to_id:
                try:
                    reply_to_obj = IncidentChatMessage.objects.get(pk=reply_to_id)
                except IncidentChatMessage.DoesNotExist:
                    pass

            chat_msg = IncidentChatService.create_chat_message(
                incident=incident,
                sender=request.user,
                message=msg_text,
                message_type=msg_type,
                attachment=attachment,
                latitude=latitude,
                longitude=longitude,
                reply_to=reply_to_obj
            )

            serializer = IncidentChatMessageSerializer(chat_msg)
            return Response({
                "success": True,
                "message": serializer.data
            }, status=status.HTTP_201_CREATED)

        except ValueError as exc:
            return Response({"error": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        except PermissionError as exc:
            return Response({"error": str(exc)}, status=status.HTTP_403_FORBIDDEN)
        except Exception as exc:
            return Response({"error": f"Failed to send message: {str(exc)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class SOSChatMessageDetailAPIView(APIView):
    """
    DELETE /api/sos/incidents/{id}/chat/{message_id}/
    Soft-delete own message.
    """
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, pk, message_id):
        try:
            msg = IncidentChatMessage.objects.get(pk=message_id, incident_id=pk)
        except IncidentChatMessage.DoesNotExist:
            return Response({"error": "Chat message not found."}, status=status.HTTP_404_NOT_FOUND)

        if msg.sender_id != request.user.id and getattr(request.user, 'role', '') not in ['ADMIN', 'STAFF']:
            return Response({"error": "You can only delete your own messages."}, status=status.HTTP_403_FORBIDDEN)

        msg.is_deleted = True
        msg.message = "This message was deleted."
        msg.save()

        IncidentChatService.broadcast_message(msg)

        return Response({"success": True, "message": "Message deleted."}, status=status.HTTP_200_OK)


class IncidentResponseUpdateAPIView(APIView):
    """
    GET /api/sos/incidents/{id}/updates/
    Retrieve response updates feed for an incident.

    POST /api/sos/incidents/{id}/updates/
    Post a new response update (TEXT, ARRIVAL, MEDICAL, SECURITY, NOTE).
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        try:
            incident = SOSIncident.objects.select_related("resident", "assigned_responder").get(pk=pk)
        except SOSIncident.DoesNotExist:
            return Response({"error": "Incident not found."}, status=status.HTTP_404_NOT_FOUND)

        if not IncidentChatService.is_participant(incident, request.user):
            return Response({"error": "Only incident participants can view response updates."}, status=status.HTTP_403_FORBIDDEN)

        qs = IncidentResponseUpdate.objects.filter(incident=incident).select_related("author")

        update_type_filter = request.query_params.get("update_type")
        if update_type_filter:
            qs = qs.filter(update_type=update_type_filter)

        role_filter = request.query_params.get("role")
        if role_filter:
            qs = qs.filter(role=role_filter)

        search_query = request.query_params.get("search")
        if search_query:
            qs = qs.filter(message__icontains=search_query)

        ordering = request.query_params.get("ordering", "created_at")
        if ordering in ["created_at", "-created_at"]:
            qs = qs.order_by(ordering)
        else:
            qs = qs.order_by("created_at")

        paginator = PageNumberPagination()
        paginator.page_size = 50
        page = paginator.paginate_queryset(qs, request)
        if page is not None:
            serializer = IncidentResponseUpdateSerializer(page, many=True)
            return paginator.get_paginated_response(serializer.data)

        serializer = IncidentResponseUpdateSerializer(qs, many=True)
        return Response({
            "success": True,
            "incident_id": pk,
            "count": qs.count(),
            "results": serializer.data
        }, status=status.HTTP_200_OK)

    def post(self, request, pk):
        try:
            incident = SOSIncident.objects.select_related("resident", "assigned_responder").get(pk=pk)
        except SOSIncident.DoesNotExist:
            return Response({"error": "Incident not found."}, status=status.HTTP_404_NOT_FOUND)

        try:
            msg_text = request.data.get("message", "")
            update_type = request.data.get("update_type", "TEXT")
            visibility = request.data.get("visibility", "PUBLIC")
            attachment = request.FILES.get("attachment")
            latitude = request.data.get("latitude")
            longitude = request.data.get("longitude")

            update = IncidentResponseUpdateService.create_response_update(
                incident=incident,
                author=request.user,
                update_type=update_type,
                message=msg_text,
                visibility=visibility,
                attachment=attachment,
                latitude=latitude,
                longitude=longitude
            )

            serializer = IncidentResponseUpdateSerializer(update)
            return Response({
                "success": True,
                "update": serializer.data
            }, status=status.HTTP_201_CREATED)

        except ValueError as exc:
            return Response({"error": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        except PermissionError as exc:
            return Response({"error": str(exc)}, status=status.HTTP_403_FORBIDDEN)
        except Exception as exc:
            return Response({"error": f"Failed to post update: {str(exc)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


from .models import BroadcastLog
from .serializers import BroadcastLogSerializer

class CommunityBroadcastAPIView(APIView):
    """
    POST /api/sos/broadcast/
    Trigger intelligent community broadcast alert to nearby Volunteers and Security Staff based on distance radius (Haversine formula).
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk=None):
        incident_id = pk or request.data.get("incident_id")
        target_role = str(request.data.get("target_role", "ALL")).upper()
        radius_km = float(request.data.get("radius_km", 5.0))
        custom_msg = request.data.get("message")

        if not incident_id:
            return Response({"error": "incident_id is required."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            incident = SOSIncident.objects.select_related("resident", "category").get(pk=incident_id)
        except SOSIncident.DoesNotExist:
            return Response({"error": "SOS incident not found."}, status=status.HTTP_404_NOT_FOUND)

        inc_lat = incident.latitude
        inc_lon = incident.longitude
        resident_name = incident.resident.full_name if incident.resident else "Resident"
        incident_society_id = incident.resident.resident_profile.society_id if (incident.resident and hasattr(incident.resident, 'resident_profile')) else None

        from accounts.models import VolunteerProfile, SecurityProfile, CustomUser
        from .services import haversine
        from notifications.dispatcher import NotificationDispatcher

        notified_users = set()
        broadcast_logs = []

        # 1. Target Volunteers
        if target_role in ["VOLUNTEER", "ALL"]:
            volunteers = VolunteerProfile.objects.filter(
                is_online=True,
                status="Approved",
                latitude__isnull=False,
                longitude__isnull=False
            ).select_related("user")

            for vol in volunteers:
                if vol.user and vol.user.is_active and vol.user.id not in notified_users and vol.user != incident.resident:
                    if inc_lat is not None and inc_lon is not None:
                        dist_m = haversine(inc_lat, inc_lon, vol.latitude, vol.longitude)
                        dist_km = dist_m / 1000.0
                    else:
                        dist_km = 0.0

                    if dist_km <= radius_km or (incident_society_id and vol.assigned_society_id == incident_society_id):
                        notified_users.add(vol.user.id)
                        msg_text = custom_msg or f"EMERGENCY BROADCAST: Resident {resident_name} triggered SOS near {incident.address or 'your area'}. Distance: {dist_km:.2f}km."
                        
                        NotificationDispatcher._dispatch_to_user(
                            user=vol.user,
                            title="🚨 Community Emergency Broadcast",
                            message=msg_text,
                            category="sos",
                            incident=incident,
                            recipient_role="VOLUNTEER",
                            notification_type="SOS_CREATED",
                            priority="HIGH",
                            channels=["IN_APP", "FCM", "EMAIL"]
                        )
                        log_obj = BroadcastLog.objects.create(
                            incident=incident,
                            target_role="VOLUNTEER",
                            recipient=vol.user,
                            recipient_name=vol.user.full_name,
                            distance_km=dist_km,
                            radius_km=radius_km,
                            status="SUCCESS",
                            delivery_channel="IN_APP",
                            message=msg_text
                        )
                        broadcast_logs.append(log_obj)

        # 2. Target Security Staff
        if target_role in ["SECURITY", "ALL"]:
            sec_profiles = SecurityProfile.objects.filter(
                is_on_duty=True,
                employment_status="Active"
            ).select_related("user")

            for sec in sec_profiles:
                if sec.user and sec.user.is_active and sec.user.id not in notified_users and sec.user != incident.resident:
                    dist_km = (haversine(inc_lat, inc_lon, sec.latitude, sec.longitude) / 1000.0) if (inc_lat is not None and inc_lon is not None and sec.latitude is not None and sec.longitude is not None) else 0.0
                    if (incident_society_id and sec.assigned_society_id == incident_society_id) or dist_km <= radius_km:
                        notified_users.add(sec.user.id)
                        msg_text = custom_msg or f"SECURITY ALERT: SOS Incident #{incident.id} for {resident_name} at {incident.address or 'society Premises'}."
                        
                        NotificationDispatcher._dispatch_to_user(
                            user=sec.user,
                            title="⚠️ Security Emergency Alert",
                            message=msg_text,
                            category="sos",
                            incident=incident,
                            recipient_role="SECURITY",
                            notification_type="SOS_CREATED",
                            priority="CRITICAL",
                            channels=["IN_APP", "FCM", "EMAIL", "SMS"]
                        )
                        log_obj = BroadcastLog.objects.create(
                            incident=incident,
                            target_role="SECURITY",
                            recipient=sec.user,
                            recipient_name=sec.user.full_name,
                            distance_km=dist_km,
                            radius_km=radius_km,
                            status="SUCCESS",
                            delivery_channel="IN_APP",
                            message=msg_text
                        )
                        broadcast_logs.append(log_obj)

        # If no responders were found/notified within radius
        if not broadcast_logs:
            log_obj = BroadcastLog.objects.create(
                incident=incident,
                target_role=target_role,
                status="NO_RESPONDERS_NEARBY",
                radius_km=radius_km,
                message=f"No active responders found within {radius_km}km radius."
            )
            broadcast_logs.append(log_obj)

        volunteers_notified = sum(1 for log in broadcast_logs if log.target_role == "VOLUNTEER" and log.status == "SUCCESS")
        security_notified = sum(1 for log in broadcast_logs if log.target_role == "SECURITY" and log.status == "SUCCESS")

        return Response({
            "success": True,
            "incident_id": incident.id,
            "target_role": target_role,
            "radius_km": radius_km,
            "total_notified": len(notified_users),
            "volunteers_notified": volunteers_notified,
            "security_notified": security_notified,
            "logs_created": len(broadcast_logs),
            "status": "SUCCESS" if len(notified_users) > 0 else "NO_RESPONDERS_NEARBY",
            "message": f"Broadcast sent to {len(notified_users)} nearby responders within {radius_km}km." if len(notified_users) > 0 else f"No active responders found within {radius_km}km."
        }, status=status.HTTP_200_OK)


class BroadcastLogViewSet(viewsets.ReadOnlyModelViewSet):
    """
    GET /api/sos/broadcast/logs/
    List and retrieve broadcast logs with filtering by incident, target_role, and status.
    """
    queryset = BroadcastLog.objects.select_related("incident", "recipient").all()
    serializer_class = BroadcastLogSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ["recipient_name", "message", "status", "target_role"]
    ordering_fields = ["created_at", "distance_km"]
    ordering = ["-created_at"]

    def get_queryset(self):
        qs = super().get_queryset()
        incident_id = self.request.query_params.get("incident")
        role = self.request.query_params.get("target_role")
        status_param = self.request.query_params.get("status")
        if incident_id:
            qs = qs.filter(incident_id=incident_id)
        if role:
            qs = qs.filter(target_role__iexact=role)
        if status_param:
            qs = qs.filter(status__iexact=status_param)
        return qs


class BroadcastHistoryAPIView(APIView):
    """
    GET /api/sos/broadcast/history/
    Returns broadcast summary history for active and historical incidents.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        incident_id = request.query_params.get("incident_id")
        qs = BroadcastLog.objects.select_related("incident", "recipient").all()
        if incident_id:
            qs = qs.filter(incident_id=incident_id)
        
        serializer = BroadcastLogSerializer(qs[:100], many=True)
        return Response({
            "count": qs.count(),
            "results": serializer.data
        }, status=status.HTTP_200_OK)

