from rest_framework import viewsets, filters, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Relationship, VerificationStatus, Guardian, EmergencyContact
from .serializers import RelationshipSerializer, VerificationStatusSerializer, GuardianSerializer, EmergencyContactSerializer

class RelationshipViewSet(viewsets.ModelViewSet):
    queryset = Relationship.objects.all()
    serializer_class = RelationshipSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def list(self, request, *args, **kwargs):
        if not Relationship.objects.exists():
            for name in ['Family', 'Friends', 'Neighbours', 'Other']:
                Relationship.objects.get_or_create(name=name)
        return super().list(request, *args, **kwargs)

class VerificationStatusViewSet(viewsets.ModelViewSet):
    queryset = VerificationStatus.objects.all()
    serializer_class = VerificationStatusSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

class GuardianViewSet(viewsets.ModelViewSet):
    queryset = Guardian.objects.all()
    serializer_class = GuardianSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [filters.SearchFilter]
    search_fields = ['name', 'phone', 'resident__email', 'resident__full_name']

    def get_queryset(self):
        queryset = super().get_queryset()
        resident_id = self.request.query_params.get('resident')
        if resident_id:
            queryset = queryset.filter(resident_id=resident_id)
        return queryset

class EmergencyContactViewSet(viewsets.ModelViewSet):
    queryset = EmergencyContact.objects.all()
    serializer_class = EmergencyContactSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [filters.SearchFilter]
    search_fields = ['name', 'phone', 'resident__email', 'resident__full_name']

    def get_queryset(self):
        queryset = super().get_queryset()
        resident_id = self.request.query_params.get('resident')
        if resident_id:
            queryset = queryset.filter(resident_id=resident_id)
        return queryset

    @action(detail=True, methods=['post'])
    def verify(self, request, pk=None):
        contact = self.get_object()
        contact.verified = True
        
        notes = f"Verified by user {request.user.email}" if request.user.is_authenticated else "Verified"
        if not contact.verification_status:
            vs = VerificationStatus.objects.create(status='Verified', notes=notes)
            contact.verification_status = vs
        else:
            contact.verification_status.status = 'Verified'
            contact.verification_status.notes = notes
            contact.verification_status.save()
            
        contact.save()
        return Response({"message": "Emergency contact verified successfully", "verified": True})
