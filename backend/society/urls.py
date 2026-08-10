from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import SocietyViewSet, BlockTowerViewSet, FlatViewSet, SocietyStatsAPIView
from .reports_views import ReportDownloadAPIView

router = DefaultRouter()
router.register('societies', SocietyViewSet, basename='society')
router.register('blocks', BlockTowerViewSet, basename='block')
router.register('flats', FlatViewSet, basename='flat')

urlpatterns = [
    path('stats/', SocietyStatsAPIView.as_view(), name='society-stats'),
    path('reports/download/', ReportDownloadAPIView.as_view(), name='reports-download'),
    path('reports/download', ReportDownloadAPIView.as_view(), name='reports-download-noslash'),
    path('', include(router.urls)),
]
