from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import NotificationViewSet, FCMDeviceViewSet, NotificationTemplateViewSet, NotificationLogViewSet

router = DefaultRouter()
router.register('devices', FCMDeviceViewSet, basename='device')
router.register('templates', NotificationTemplateViewSet, basename='template')
router.register('logs', NotificationLogViewSet, basename='log')
router.register('', NotificationViewSet, basename='notification')

urlpatterns = [
    path('', include(router.urls)),
]

