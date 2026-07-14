from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.db.models import Q
from .models import Notification
from .serializers import NotificationSerializer

class NotificationViewSet(viewsets.ModelViewSet):
    queryset = Notification.objects.all()
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        # Return notifications targeted to this user, or general ones where user is null
        return Notification.objects.filter(
            Q(user=self.request.user) | Q(user__isnull=True)
        ).order_by('-created_at')

    @action(detail=True, methods=['post', 'patch'], url_path='read')
    def mark_read(self, request, pk=None):
        notification = self.get_object()
        notification.is_read = True
        notification.save()
        return Response({"message": "Notification marked as read", "is_read": True})

    @action(detail=False, methods=['get'], url_path='guardian')
    def guardian(self, request):
        # Return only notifications of category 'sos' targeted to this specific user (guardian)
        queryset = Notification.objects.filter(
            user=request.user,
            category='sos'
        ).order_by('-created_at')
        serializer = self.get_serializer(queryset, many=True)
        
        # Printing API Response log as requested
        print(f"API Response: {serializer.data}")
        
        return Response(serializer.data)

    @action(detail=False, methods=['post'], url_path='mark-all-read')
    def mark_all_read(self, request):
        Notification.objects.filter(
            Q(user=request.user) | Q(user__isnull=True),
            is_read=False
        ).update(is_read=True)
        return Response({"message": "All notifications marked as read"})
