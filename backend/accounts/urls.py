from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import RegisterAPIView, LoginAPIView, ResidentProfileViewSet, DashboardStatsAPIView, MeAPIView

router = DefaultRouter()
router.register('residents', ResidentProfileViewSet, basename='resident')

urlpatterns = [
    path("register/", RegisterAPIView.as_view(), name="register"),
    path("login/", LoginAPIView.as_view(), name="login"),
    path("me/", MeAPIView.as_view(), name="me"),
    path("dashboard-stats/", DashboardStatsAPIView.as_view(), name="dashboard_stats"),
    path("", include(router.urls)),
]