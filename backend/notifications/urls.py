from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    NotificationViewSet,
    FCMDeviceViewSet,
    FCMDeviceRegisterAPIView,
    NotificationTemplateViewSet,
    NotificationLogViewSet,
    SMSLogViewSet,
    UnreadCountAPIView,
    UnreadNotificationsAPIView,
    MarkNotificationReadAPIView,
    MarkAllNotificationsReadAPIView,
    NotificationHistoryAPIView,
    GuardianNotificationsAPIView,
)
from sos.analytics_views import NotificationDeliveryTrackingAPIView

router = DefaultRouter()
router.register('devices', FCMDeviceViewSet, basename='device')
router.register('templates', NotificationTemplateViewSet, basename='template')
router.register('logs', NotificationLogViewSet, basename='log')
router.register('sms-logs', SMSLogViewSet, basename='sms-log')
router.register('', NotificationViewSet, basename='notification')

urlpatterns = [
    # Explicit endpoint paths requested
    path('unread/', UnreadNotificationsAPIView.as_view(), name='notification-unread'),
    path('read/<int:pk>/', MarkNotificationReadAPIView.as_view(), name='notification-mark-read'),
    path('read-all/', MarkAllNotificationsReadAPIView.as_view(), name='notification-read-all'),
    path('count/', UnreadCountAPIView.as_view(), name='notification-count'),
    path('history/', NotificationHistoryAPIView.as_view(), name='notification-history'),
    path('guardian/', GuardianNotificationsAPIView.as_view(), name='notification-guardian'),
    path('register-token/', FCMDeviceRegisterAPIView.as_view(), name='fcm-register-token'),
    path('delivery-tracking/', NotificationDeliveryTrackingAPIView.as_view(), name='notification-delivery-tracking'),

    path('', include(router.urls)),
]

