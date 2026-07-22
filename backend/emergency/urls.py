from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    RelationshipViewSet,
    VerificationStatusViewSet,
    GuardianViewSet,
    EmergencyContactViewSet,
    EmergencyAlertView,
    GenerateGuardianCodeView,
    MyGuardianCodeView,
    LinkGuardianView,
    RespondGuardianLinkView,
    ResidentGuardiansView,
    UnlinkGuardianView,
    ChangePrimaryGuardianView
)

router = DefaultRouter()
router.register('relationships', RelationshipViewSet, basename='relationship')
router.register('verifications', VerificationStatusViewSet, basename='verification')
router.register('guardians', GuardianViewSet, basename='guardian')
router.register('contacts', EmergencyContactViewSet, basename='contact')

urlpatterns = [
    path('', include(router.urls)),
    # Flutter mobile SOS trigger endpoint
    path('alerts/', EmergencyAlertView.as_view(), name='emergency-alerts'),

    # Guardian Code Linking APIs
    path('guardian/generate-code/', GenerateGuardianCodeView.as_view(), name='guardian-generate-code-sub'),
    path('guardian/my-code/', MyGuardianCodeView.as_view(), name='guardian-my-code-sub'),
    path('guardian/respond-link/', RespondGuardianLinkView.as_view(), name='guardian-respond-link-sub'),
    path('resident/link-guardian/', LinkGuardianView.as_view(), name='resident-link-guardian-sub'),
    path('resident/unlink-guardian/', UnlinkGuardianView.as_view(), name='resident-unlink-guardian-sub'),
    path('resident/unlink-guardian/<int:pk>/', UnlinkGuardianView.as_view(), name='resident-unlink-guardian-pk-sub'),
    path('resident/guardians/', ResidentGuardiansView.as_view(), name='resident-guardians-sub'),
    path('resident/change-primary/', ChangePrimaryGuardianView.as_view(), name='resident-change-primary-sub'),
]

