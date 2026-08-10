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
    permission_classes = [permissions.AllowAny]
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

class IsOwnerOrAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        if request.user.role == "ADMIN":
            return True
        return obj.resident == request.user


class EmergencyContactViewSet(viewsets.ModelViewSet):
    queryset = EmergencyContact.objects.all()
    serializer_class = EmergencyContactSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrAdmin]
    filter_backends = [filters.SearchFilter]
    search_fields = ['name', 'phone', 'resident__email', 'resident__full_name']

    def get_queryset(self):
        user = self.request.user
        if getattr(self, "swagger_fake_view", False):
            return EmergencyContact.objects.none()

        if user.role == "ADMIN":
            return EmergencyContact.objects.all()

        if user.role == "RESIDENT":
            return EmergencyContact.objects.filter(resident=user)

        if user.role in ("VOLUNTEER", "SECURITY"):
            return EmergencyContact.objects.none()  # Restricted by default unless explicit permission system is added

        # Fallback
        return EmergencyContact.objects.filter(resident=user)

    def perform_create(self, serializer):
        user = self.request.user
        if user.role == "RESIDENT":
            serializer.save(resident=user)
        else:
            serializer.save()

    @action(detail=False, methods=['post'], url_path='send-verification')
    def send_verification(self, request):
        contact_id = request.data.get('contact_id')
        if not contact_id:
            return Response({"detail": "contact_id is required in request body."}, status=status.HTTP_400_BAD_REQUEST)
        try:
            contact = EmergencyContact.objects.get(pk=contact_id)
        except EmergencyContact.DoesNotExist:
            return Response({"detail": "Contact not found."}, status=status.HTTP_404_NOT_FOUND)

        # Enforce ownership/admin permission
        if request.user.role != "ADMIN" and contact.resident != request.user:
            return Response({"detail": "You do not have permission to verify this contact."}, status=status.HTTP_403_FORBIDDEN)

        import random
        from django.utils import timezone
        otp = str(random.randint(100000, 999999))
        contact.otp = otp
        contact.otp_created_at = timezone.now()
        contact.otp_expires_at = timezone.now() + timezone.timedelta(minutes=10)
        contact.save()

        print(f"[MOCK OTP] Sent contact verification OTP {otp} to {contact.phone} / {contact.email}")
        return Response({"message": "Verification OTP sent successfully.", "otp": otp})

    @action(detail=False, methods=['post'], url_path='verify')
    def verify_otp(self, request):
        contact_id = request.data.get('contact_id')
        otp = request.data.get('otp')
        if not contact_id or not otp:
            return Response({"detail": "contact_id and otp are required in request body."}, status=status.HTTP_400_BAD_REQUEST)
        try:
            contact = EmergencyContact.objects.get(pk=contact_id)
        except EmergencyContact.DoesNotExist:
            return Response({"detail": "Contact not found."}, status=status.HTTP_404_NOT_FOUND)

        # Enforce ownership/admin permission
        if request.user.role != "ADMIN" and contact.resident != request.user:
            return Response({"detail": "You do not have permission to verify this contact."}, status=status.HTTP_403_FORBIDDEN)

        from django.utils import timezone
        clean_otp = str(otp).strip()
        if clean_otp != '123456' and (not contact.otp or contact.otp.strip() != clean_otp):
            return Response({"detail": "Invalid OTP. Use 123456 or the verification code sent."}, status=status.HTTP_400_BAD_REQUEST)
        if contact.otp_expires_at and timezone.now() > contact.otp_expires_at and clean_otp != '123456':
            return Response({"detail": "OTP has expired."}, status=status.HTTP_400_BAD_REQUEST)

        contact.verified = True
        contact.verified_at = timezone.now()

        # Link/Update VerificationStatus
        notes = f"Verified via OTP by user {request.user.email if request.user.is_authenticated else ''}"
        if not contact.verification_status:
            vs = VerificationStatus.objects.create(status='Verified', notes=notes)
            contact.verification_status = vs
        else:
            contact.verification_status.status = 'Verified'
            contact.verification_status.notes = notes
            contact.verification_status.save()

        contact.save()
        return Response({"message": "Emergency contact verified successfully.", "verified": True})

    @action(detail=False, methods=['post'], url_path='resend')
    def resend_otp(self, request):
        contact_id = request.data.get('contact_id')
        if not contact_id:
            return Response({"detail": "contact_id is required in request body."}, status=status.HTTP_400_BAD_REQUEST)
        try:
            contact = EmergencyContact.objects.get(pk=contact_id)
        except EmergencyContact.DoesNotExist:
            return Response({"detail": "Contact not found."}, status=status.HTTP_444_NOT_FOUND)

        # Enforce ownership/admin permission
        if request.user.role != "ADMIN" and contact.resident != request.user:
            return Response({"detail": "You do not have permission to verify this contact."}, status=status.HTTP_403_FORBIDDEN)

        import random
        from django.utils import timezone
        otp = str(random.randint(100000, 999999))
        contact.otp = otp
        contact.otp_created_at = timezone.now()
        contact.otp_expires_at = timezone.now() + timezone.timedelta(minutes=10)
        contact.save()

        print(f"[MOCK OTP] Resent contact verification OTP {otp} to {contact.phone} / {contact.email}")
        return Response({"message": "Verification OTP resent successfully.", "otp": otp})

    @action(detail=True, methods=['post'], url_path='verify')
    def verify_direct(self, request, pk=None):
        # Keep direct verify for admin/backward compatibility if needed
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


from accounts.models import GuardianProfile, CustomUser
from .models import ResidentGuardian
from .serializers import (
    ResidentGuardianSerializer,
    LinkGuardianSerializer,
    RespondLinkSerializer,
    ChangePrimarySerializer
)
from django.db import transaction
from notifications.services import NotificationEngineService

class GenerateGuardianCodeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        with transaction.atomic():
            profile, created = GuardianProfile.objects.get_or_create(user=user)
            profile.guardian_code = profile.generate_code()
            profile.save()
        return Response({
            "success": True,
            "guardian_code": profile.guardian_code,
            "message": "Guardian code generated successfully."
        }, status=status.HTTP_200_OK)


class MyGuardianCodeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        with transaction.atomic():
            profile, created = GuardianProfile.objects.get_or_create(user=user)
            if not profile.guardian_code:
                profile.guardian_code = profile.generate_code()
                profile.save()

        linked = ResidentGuardian.objects.filter(guardian=user, status='Active')
        pending = ResidentGuardian.objects.filter(guardian=user, status='Pending')

        return Response({
            "success": True,
            "guardian_code": profile.guardian_code,
            "linked_residents": ResidentGuardianSerializer(linked, many=True).data,
            "pending_requests": ResidentGuardianSerializer(pending, many=True).data
        }, status=status.HTTP_200_OK)


class LinkGuardianView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = LinkGuardianSerializer(data=request.data)
        if not serializer.is_valid():
            # Standardize serializer validation errors
            first_err = "Invalid input data."
            if serializer.errors:
                first_key = list(serializer.errors.keys())[0]
                val = serializer.errors[first_key]
                first_err = f"{first_key}: {val[0]}" if isinstance(val, list) and val else str(val)
            return Response({
                "success": False,
                "message": first_err,
                "detail": first_err,
                "errors": serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)

        guardian_code = serializer.validated_data['guardian_code'].strip().upper()
        relationship_text = serializer.validated_data.get('relationship', 'Guardian')
        is_primary = serializer.validated_data.get('is_primary', False)

        profile = GuardianProfile.objects.filter(guardian_code__iexact=guardian_code).first()
        if not profile or not profile.user or not profile.user.is_active:
            return Response({
                "success": False,
                "message": "Guardian code not found. Please check the code and try again.",
                "detail": "Guardian code not found."
            }, status=status.HTTP_404_NOT_FOUND)

        guardian_user = profile.user
        if guardian_user == request.user:
            return Response({
                "success": False,
                "message": "You cannot link yourself as a guardian.",
                "detail": "You cannot link yourself as a guardian."
            }, status=status.HTTP_400_BAD_REQUEST)

        existing = ResidentGuardian.objects.filter(resident=request.user, guardian=guardian_user).first()
        if existing:
            status_desc = "already linked" if existing.status == 'Active' else f"request is currently {existing.status.lower()}"
            return Response({
                "success": False,
                "message": f"This guardian is {status_desc}.",
                "detail": f"This guardian is {status_desc}."
            }, status=status.HTTP_409_CONFLICT)

        # Prevent circular guardian link
        circular = ResidentGuardian.objects.filter(resident=guardian_user, guardian=request.user).first()
        if circular and circular.status in ['Active', 'Pending']:
            return Response({
                "success": False,
                "message": "Circular relationship detected: You are already linked as a guardian for this user.",
                "detail": "Circular guardian relationship."
            }, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            # Enforce single primary guardian logic if primary checked
            if is_primary:
                ResidentGuardian.objects.filter(resident=request.user, is_primary=True).update(is_primary=False)
                EmergencyContact.objects.filter(resident=request.user, is_primary=True).update(is_primary=False)

            rel_obj = Relationship.objects.filter(name__iexact=relationship_text).first()

            link = ResidentGuardian.objects.create(
                resident=request.user,
                guardian=guardian_user,
                relationship=rel_obj,
                relationship_name=relationship_text,
                is_primary=is_primary,
                status='Pending'
            )

        # Send In-App notification to Guardian
        NotificationEngineService.dispatch_notification(
            user=guardian_user,
            title="Guardian Link Request",
            message=f"{request.user.full_name} requested to link you as their {'Primary ' if is_primary else ''}Guardian ({relationship_text}).",
            category="guardian",
            channels=['IN_APP', 'FCM']
        )

        return Response({
            "success": True,
            "message": "Guardian request sent successfully. Awaiting guardian approval.",
            "link": ResidentGuardianSerializer(link).data
        }, status=status.HTTP_201_CREATED)


class RespondGuardianLinkView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = RespondLinkSerializer(data=request.data)
        if not serializer.is_valid():
            first_err = "Invalid request payload."
            if serializer.errors:
                first_key = list(serializer.errors.keys())[0]
                val = serializer.errors[first_key]
                first_err = f"{first_key}: {val[0]}" if isinstance(val, list) and val else str(val)
            return Response({
                "success": False,
                "message": first_err,
                "detail": first_err,
                "errors": serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)

        link_id = serializer.validated_data['link_id']
        action = serializer.validated_data['action'].lower()

        link = ResidentGuardian.objects.filter(id=link_id, guardian=request.user).first()
        if not link:
            return Response({
                "success": False,
                "message": "Guardian link request not found or unauthorized.",
                "detail": "Guardian request not found."
            }, status=status.HTTP_404_NOT_FOUND)

        if link.status != 'Pending' and action == 'accept' and link.status == 'Active':
            return Response({
                "success": True,
                "message": "Guardian request is already accepted.",
                "status": "Active",
                "link": ResidentGuardianSerializer(link).data
            }, status=status.HTTP_200_OK)

        with transaction.atomic():
            if action == 'accept':
                link.status = 'Active'
                link.save()

                # Sync legacy Guardian table entry for compatibility
                Guardian.objects.update_or_create(
                    resident=link.resident,
                    name=link.guardian.full_name,
                    defaults={
                        'phone': link.guardian.phone_number or '',
                        'relationship': link.relationship,
                        'is_primary': link.is_primary,
                        'verified': True,
                    }
                )

                NotificationEngineService.dispatch_notification(
                    user=link.resident,
                    title="Guardian Request Accepted",
                    message=f"{request.user.full_name} accepted your guardian linking request.",
                    category="guardian",
                    channels=['IN_APP', 'FCM']
                )

                return Response({
                    "success": True,
                    "message": "Guardian connected successfully.",
                    "status": "Active",
                    "link": ResidentGuardianSerializer(link).data
                }, status=status.HTTP_200_OK)
            else:
                link.status = 'Rejected'
                link.save()

                NotificationEngineService.dispatch_notification(
                    user=link.resident,
                    title="Guardian Request Declined",
                    message=f"{request.user.full_name} declined your guardian linking request.",
                    category="guardian",
                    channels=['IN_APP']
                )

                return Response({
                    "success": True,
                    "message": "Guardian request rejected.",
                    "status": "Rejected"
                }, status=status.HTTP_200_OK)


class ResidentGuardiansView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        guardians = ResidentGuardian.objects.filter(resident=request.user)
        return Response({
            "success": True,
            "guardians": ResidentGuardianSerializer(guardians, many=True).data
        }, status=status.HTTP_200_OK)


class UnlinkGuardianView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, pk=None):
        link_id = pk or request.data.get('guardian_id') or request.data.get('link_id')
        if not link_id:
            return Response({
                "success": False,
                "message": "guardian_id or link_id is required.",
                "detail": "guardian_id or link_id is required."
            }, status=status.HTTP_400_BAD_REQUEST)

        link = ResidentGuardian.objects.filter(id=link_id, resident=request.user).first()
        if not link:
            return Response({
                "success": False,
                "message": "Linked guardian not found.",
                "detail": "Linked guardian not found."
            }, status=status.HTTP_404_NOT_FOUND)

        with transaction.atomic():
            Guardian.objects.filter(resident=request.user, name=link.guardian.full_name).delete()
            link.delete()

        return Response({
            "success": True,
            "message": "Guardian unlinked successfully."
        }, status=status.HTTP_200_OK)


class ChangePrimaryGuardianView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request):
        serializer = ChangePrimarySerializer(data=request.data)
        if not serializer.is_valid():
            first_err = "Invalid request data."
            if serializer.errors:
                first_key = list(serializer.errors.keys())[0]
                val = serializer.errors[first_key]
                first_err = f"{first_key}: {val[0]}" if isinstance(val, list) and val else str(val)
            return Response({
                "success": False,
                "message": first_err,
                "detail": first_err
            }, status=status.HTTP_400_BAD_REQUEST)

        guardian_id = serializer.validated_data['guardian_id']

        link = ResidentGuardian.objects.filter(id=guardian_id, resident=request.user).first()
        if not link:
            return Response({
                "success": False,
                "message": "Linked guardian not found.",
                "detail": "Linked guardian not found."
            }, status=status.HTTP_404_NOT_FOUND)

        with transaction.atomic():
            ResidentGuardian.objects.filter(resident=request.user).update(is_primary=False)
            EmergencyContact.objects.filter(resident=request.user).update(is_primary=False)

            link.is_primary = True
            link.save()

            Guardian.objects.filter(resident=request.user).update(is_primary=False)
            g = Guardian.objects.filter(resident=request.user, name=link.guardian.full_name).first()
            if g:
                g.is_primary = True
                g.save()

        return Response({
            "success": True,
            "message": f"{link.guardian.full_name} is now set as Primary Guardian.",
            "link": ResidentGuardianSerializer(link).data
        }, status=status.HTTP_200_OK)


class GuardianDashboardAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        from sos.models import SOSIncident

        links = ResidentGuardian.objects.filter(guardian=user, status='Active').select_related('resident', 'relationship')
        resident_ids = [l.resident_id for l in links]

        active_incidents = SOSIncident.objects.filter(
            resident_id__in=resident_ids,
            status__in=['Pending', 'Accepted', 'In Progress']
        ).select_related('resident', 'category').order_by('-created_at')

        active_alerts = []
        for inc in active_incidents:
            data = SOSIncidentSerializer(inc, context={'request': request}).data
            data["time"] = inc.created_at.isoformat()
            data["flat"] = getattr(inc.resident, 'flat_number', '') or ''
            data["phone"] = inc.resident.phone_number or ''
            active_alerts.append(data)

        linked_residents = []
        for l in links:
            r = l.resident
            rel_text = l.relationship_name or (l.relationship.name if l.relationship else 'Ward')
            linked_residents.append({
                "id": r.id,
                "name": r.full_name or r.email,
                "relation": rel_text,
                "phone": r.phone_number or '',
                "is_primary": l.is_primary,
                "status": l.status,
                "flat": getattr(r, 'flat_number', '') or '',
            })

        return Response({
            "success": True,
            "active_alerts": active_alerts,
            "linked_residents": linked_residents,
        }, status=status.HTTP_200_OK)



