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
)
from .filters import SOSIncidentFilter
from .permissions import (
    CanViewSOS,
    IsSocietyManagerOrAdmin,
    IsSecurityRole,
    ROLE_ADMIN,
    ROLE_SOCIETY_MANAGER,
    ROLE_SECURITY,
)
from .services import SOSService


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_scoped_queryset(user):
    """Return incidents visible to *user* based on their role."""
    qs = SOSIncident.objects.select_related("resident", "category")
    if user.role in (ROLE_ADMIN, ROLE_SOCIETY_MANAGER, ROLE_SECURITY):
        return qs.all()
    # Residents only see their own
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
        return _get_scoped_queryset(self.request.user)


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
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

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
    permission_classes = [permissions.IsAuthenticated, IsSocietyManagerOrAdmin]
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

        # Security may also update status
        user = request.user
        if user.role not in (ROLE_ADMIN, ROLE_SOCIETY_MANAGER, ROLE_SECURITY):
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


@extend_schema(tags=["SOS — Messages"], request=SOSEmergencyMessageSerializer, responses={201: SOSEmergencyMessageSerializer})
class SOSEmergencyMessageCreateView(generics.CreateAPIView):
    """
    POST /api/sos/{id}/message/
    Allow resident to attach an additional emergency text message.
    """
    serializer_class = SOSEmergencyMessageSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        incident_pk = self.kwargs.get("pk")
        try:
            incident = SOSIncident.objects.get(pk=incident_pk)
        except SOSIncident.DoesNotExist:
            raise permissions.exceptions.ValidationError("SOS incident not found.")

        # Check access permission
        user = self.request.user
        if user.role == "RESIDENT" and incident.resident != user:
            raise permissions.exceptions.PermissionDenied(
                "You do not have permission to attach a message to this incident."
            )

        serializer.save(incident=incident, sender=user)


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