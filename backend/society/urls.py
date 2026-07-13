from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import SocietyViewSet, BlockTowerViewSet, FlatViewSet

router = DefaultRouter()
router.register('societies', SocietyViewSet, basename='society')
router.register('blocks', BlockTowerViewSet, basename='block')
router.register('flats', FlatViewSet, basename='flat')

urlpatterns = [
    path('', include(router.urls)),
]
