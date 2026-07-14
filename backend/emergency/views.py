from rest_framework import viewsets, filters, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import Relationship, VerificationStatus, Guardian, EmergencyContact
from .serializers import RelationshipSerializer, VerificationStatusSerializer, GuardianSerializer, EmergencyContactSerializer
from sos.models import EmergencyCategory
from sos.services import SOSService
from sos.serializers import SOSIncidentSerializer

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


class EmergencyAlertView(APIView):
    """
    POST /api/emergency/alerts/

    Flutter mobile endpoint for triggering an SOS alert.
    Accepts:
      - category (str): slug name of the emergency type e.g. 'SOS', 'fire', 'ambulance'
      - message  (str): optional description
      - latitude / longitude (optional)

    Maps the category slug to an EmergencyCategory (creates one if needed),
    then delegates to SOSService to create the incident + fire notification.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        category_slug = (request.data.get('category') or 'SOS').strip()
        message = request.data.get('message', '')
        latitude = request.data.get('latitude')
        longitude = request.data.get('longitude')

        # Find or create matching EmergencyCategory (case-insensitive name match)
        category = EmergencyCategory.objects.filter(name__iexact=category_slug).first()
        if category is None:
            category = EmergencyCategory.objects.create(
                name=category_slug.title(),
                is_active=True,
            )

        if not category.is_active:
            return Response(
                {'detail': f'Emergency category "{category.name}" is currently inactive.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        incident_data = {
            'category': category,
            'message': message[:500] if message else '',
        }
        if latitude is not None:
            incident_data['latitude'] = latitude
        if longitude is not None:
            incident_data['longitude'] = longitude

        incident = SOSService.create_incident(user=request.user, validated_data=incident_data)

        return Response(
            {
                'message': 'SOS alert received. Help is on the way.',
                'incident': SOSIncidentSerializer(incident, context={'request': request}).data,
            },
            status=status.HTTP_201_CREATED,
        )
