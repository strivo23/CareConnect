from rest_framework import viewsets, filters, permissions, status
from rest_framework.decorators import action
from rest_framework.views import APIView
from rest_framework.response import Response
from django.db.models import Q
from .models import Society, BlockTower, Flat
from .serializers import SocietySerializer, BlockTowerSerializer, FlatSerializer
from accounts.models import User, ResidentProfile, VolunteerProfile, SecurityProfile, GuardianProfile, UserDocument
from accounts.serializers import UserSerializer

class SocietyViewSet(viewsets.ModelViewSet):
    queryset = Society.objects.all()
    serializer_class = SocietySerializer
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'code', 'city', 'state', 'country', 'address', 'description']
    ordering_fields = ['name', 'city', 'state', 'created_at']
    ordering = ['-created_at']

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        user = self.request.user
        qs = super().get_queryset()
        if user and user.is_authenticated and getattr(user, 'role', None) == 'SOCIETY_MANAGER':
            return qs.filter(Q(society_manager=user) | Q(email=user.email))
        return qs

    @action(detail=True, methods=['post'], url_path='assign-manager')
    def assign_manager(self, request, pk=None):
        """
        POST /api/society/societies/{id}/assign-manager/
        Assigns or updates the Society Manager foreign key linking for a society without modifying society metadata.
        Body: { "manager_id": <user_id> } or { "manager_id": null }
        """
        society = self.get_object()
        manager_id = request.data.get('manager_id')

        if manager_id:
            manager = User.objects.filter(id=manager_id).first()
            if not manager:
                return Response({'detail': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)
            
            # Ensure manager role is updated to SOCIETY_MANAGER if needed
            if manager.role not in ['ADMIN', 'SOCIETY_MANAGER', 'STAFF']:
                manager.role = 'SOCIETY_MANAGER'
                manager.save()

            society.society_manager = manager
            msg = f"Manager '{manager.full_name}' assigned to society '{society.name}' successfully."
        else:
            society.society_manager = None
            msg = f"Manager unassigned from society '{society.name}' successfully."

        society.save()
        return Response({'message': msg, 'society': SocietySerializer(society).data}, status=status.HTTP_200_OK)

    @action(detail=False, methods=['get'], url_path='eligible-managers')
    def eligible_managers(self, request):
        """
        GET /api/society/societies/eligible-managers/
        Returns list of verified users available for manager assignment.
        """
        users = User.objects.filter(Q(role__in=['ADMIN', 'SOCIETY_MANAGER', 'STAFF']) | Q(is_superuser=True)).order_by('full_name')
        return Response(UserSerializer(users, many=True).data, status=status.HTTP_200_OK)


class BlockTowerViewSet(viewsets.ModelViewSet):
    queryset = BlockTower.objects.all()
    serializer_class = BlockTowerSerializer
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name']
    ordering_fields = ['name', 'total_floors', 'total_flats']
    ordering = ['name']

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        queryset = super().get_queryset()
        society_id = self.request.query_params.get('society')
        if society_id:
            queryset = queryset.filter(society_id=society_id)
        return queryset


class FlatViewSet(viewsets.ModelViewSet):
    queryset = Flat.objects.all()
    serializer_class = FlatSerializer
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['flat_number', 'type', 'owner_name', 'resident_name']
    ordering_fields = ['flat_number', 'floor']
    ordering = ['flat_number']

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        queryset = super().get_queryset()
        society_id = self.request.query_params.get('society')
        block_id = self.request.query_params.get('block')
        occupied = self.request.query_params.get('occupied')

        if society_id:
            queryset = queryset.filter(block__society_id=society_id)
        if block_id:
            queryset = queryset.filter(block_id=block_id)
        if occupied is not None:
            is_occupied = occupied.lower() == 'true'
            queryset = queryset.filter(occupied=is_occupied)

        return queryset


class SocietyStatsAPIView(APIView):
    """
    GET /api/society/stats/
    Returns KPI telemetry stats for Admin Dashboard.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        total_societies = Society.objects.count()
        active_societies = Society.objects.filter(status='Active').count()

        residents_count = ResidentProfile.objects.count()
        verified_residents = ResidentProfile.objects.filter(status='Approved').count()
        pending_residents = ResidentProfile.objects.filter(status='Pending').count()

        volunteers_count = VolunteerProfile.objects.count()
        security_count = SecurityProfile.objects.count()

        total_flats = Flat.objects.count()
        occupied_flats = Flat.objects.filter(occupied=True).count()
        vacant_flats = Flat.objects.filter(occupied=False).count()

        pending_volunteers = VolunteerProfile.objects.filter(status='Pending').count()
        pending_security = SecurityProfile.objects.filter(verification_status='Pending').count()
        pending_guardians = GuardianProfile.objects.filter(verification_status='Pending').count()

        total_pending_verifications = pending_residents + pending_volunteers + pending_security + pending_guardians

        return Response({
            "total_societies": total_societies,
            "active_societies": active_societies,
            "residents_count": residents_count,
            "verified_residents": verified_residents,
            "pending_verifications": total_pending_verifications,
            "volunteers_count": volunteers_count,
            "security_count": security_count,
            "total_flats": total_flats,
            "occupied_flats": occupied_flats,
            "vacant_flats": vacant_flats,
            "pending_requests": {
                "residents": pending_residents,
                "volunteers": pending_volunteers,
                "security": pending_security,
                "guardians": pending_guardians
            }
        }, status=status.HTTP_200_OK)
