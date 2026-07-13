from rest_framework import viewsets, filters
from .models import Society, BlockTower, Flat
from .serializers import SocietySerializer, BlockTowerSerializer, FlatSerializer

class SocietyViewSet(viewsets.ModelViewSet):
    queryset = Society.objects.all()
    serializer_class = SocietySerializer
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'city', 'state', 'address', 'contact_person']
    ordering_fields = ['name', 'city', 'state', 'created_at']
    ordering = ['-created_at']

class BlockTowerViewSet(viewsets.ModelViewSet):
    queryset = BlockTower.objects.all()
    serializer_class = BlockTowerSerializer
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name']
    ordering_fields = ['name', 'total_floors']
    ordering = ['name']

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
    search_fields = ['flat_number', 'type']
    ordering_fields = ['flat_number', 'floor']
    ordering = ['flat_number']

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
