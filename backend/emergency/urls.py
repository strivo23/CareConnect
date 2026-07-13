from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import RelationshipViewSet, VerificationStatusViewSet, GuardianViewSet, EmergencyContactViewSet

router = DefaultRouter()
router.register('relationships', RelationshipViewSet, basename='relationship')
router.register('verifications', VerificationStatusViewSet, basename='verification')
router.register('guardians', GuardianViewSet, basename='guardian')
router.register('contacts', EmergencyContactViewSet, basename='contact')

urlpatterns = [
    path('', include(router.urls)),
]
