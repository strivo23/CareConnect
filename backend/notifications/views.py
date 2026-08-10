from django.utils import timezone
from django.db.models import Q
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.pagination import PageNumberPagination

from .models import Notification, FCMDevice, NotificationTemplate, NotificationLog, SMSLog
from .serializers import (
    NotificationSerializer,
    FCMDeviceSerializer,
    NotificationTemplateSerializer,
    NotificationLogSerializer,
    SMSLogSerializer,
)


class NotificationPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


class NotificationViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Notifications with:
      - Pagination (20 notifications per request)
      - User ownership scoping & Admin override
      - Database index performance optimizations
      - Full audit logging for Created, Read, and Deleted events
    """
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = NotificationPagination

    def get_queryset(self):
        user = self.request.user

        # Security Scoping: Admin sees all; Regular users see only their own (or null broadcast)
        if getattr(user, 'role', '') == 'ADMIN' or user.is_staff:
            qs = Notification.objects.all()
        else:
            qs = Notification.objects.filter(Q(user=user) | Q(user__isnull=True))

        # Query Filters
        category = self.request.query_params.get('category')
        if category and category.lower() != 'all':
            if category.lower() == 'emergency' or category.lower() == 'sos':
                qs = qs.filter(Q(category__iexact='sos') | Q(category__iexact='emergency'))
            else:
                qs = qs.filter(category__iexact=category)

        priority = self.request.query_params.get('priority')
        if priority:
            qs = qs.filter(priority__iexact=priority)

        recipient_role = self.request.query_params.get('recipient_role')
        if recipient_role:
            qs = qs.filter(recipient_role__iexact=recipient_role)

        is_read = self.request.query_params.get('is_read')
        if is_read is not None:
            if is_read.lower() in ['true', '1']:
                qs = qs.filter(is_read=True)
            elif is_read.lower() in ['false', '0']:
                qs = qs.filter(is_read=False)

        # Sorting
        sort_by = self.request.query_params.get('sort_by') or self.request.query_params.get('ordering')
        if sort_by == 'priority':
            qs = qs.order_by('-priority', '-created_at')
        elif sort_by == 'unread':
            qs = qs.order_by('is_read', '-created_at')
        else:
            qs = qs.order_by('-created_at')

        return qs

    def get_object(self):
        pk = self.kwargs.get('pk')
        user = self.request.user
        
        # Ownership check for 403 Forbidden vs 404 Not Found
        try:
            notification = Notification.objects.get(pk=pk)
        except Notification.DoesNotExist:
            from rest_framework.exceptions import NotFound
            raise NotFound("Notification not found.")

        if not (user.is_staff or getattr(user, 'role', '') == 'ADMIN') and notification.user and notification.user != user:
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("You do not have permission to access or modify this notification.")

        return notification


    def destroy(self, request, *args, **kwargs):
        """
        Delete single notification with strict recipient ownership validation.
        """
        notification = self.get_object()
        user = request.user

        # Ownership validation
        if not (user.is_staff or getattr(user, 'role', '') == 'ADMIN') and notification.user and notification.user != user:
            return Response(
                {"detail": "You do not have permission to delete this notification."},
                status=status.HTTP_403_FORBIDDEN
            )

        # Record Audit Log
        NotificationLog.objects.create(
            user=user,
            channel='IN_APP_DELETED',
            status='SUCCESS',
            recipient=user.email,
            title=notification.title,
            message=f"Notification #{notification.id} deleted by user."
        )

        return super().destroy(request, *args, **kwargs)

    @action(detail=True, methods=['post', 'patch'], url_path='read')
    def mark_read(self, request, pk=None):
        """
        Mark specific notification read with recipient ownership validation.
        """
        notification = self.get_object()
        user = request.user

        if not (user.is_staff or getattr(user, 'role', '') == 'ADMIN') and notification.user and notification.user != user:
            return Response(
                {"detail": "You do not have permission to modify this notification."},
                status=status.HTTP_403_FORBIDDEN
            )

        if not notification.is_read:
            notification.is_read = True
            notification.read_time = timezone.now()
            notification.save(update_fields=['is_read', 'read_time'])

            # Audit Log
            NotificationLog.objects.create(
                user=user,
                channel='IN_APP_READ',
                status='SUCCESS',
                recipient=user.email,
                title=notification.title,
                message=f"Notification #{notification.id} marked read."
            )

        return Response(NotificationSerializer(notification).data, status=status.HTTP_200_OK)

    @action(detail=False, methods=['get'], url_path='unread')
    def unread(self, request):
        """GET /api/notifications/unread/"""
        qs = self.get_queryset().filter(is_read=False)
        page = self.paginate_queryset(qs)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'], url_path='count')
    def count(self, request):
        """GET /api/notifications/count/ - Lightweight unread count"""
        user = request.user
        if getattr(user, 'role', '') == 'ADMIN' or user.is_staff:
            unread_count = Notification.objects.filter(is_read=False).count()
        else:
            unread_count = Notification.objects.filter(
                Q(user=user) | Q(user__isnull=True),
                is_read=False
            ).count()
        return Response({"unread_count": unread_count})

    @action(detail=False, methods=['post'], url_path='read-all')
    def mark_all_read(self, request):
        """POST /api/notifications/read-all/"""
        user = request.user
        now = timezone.now()

        if getattr(user, 'role', '') == 'ADMIN' or user.is_staff:
            qs = Notification.objects.filter(is_read=False)
        else:
            qs = Notification.objects.filter(Q(user=user) | Q(user__isnull=True), is_read=False)

        updated_count = qs.update(is_read=True, read_time=now)

        NotificationLog.objects.create(
            user=user,
            channel='IN_APP_READ_ALL',
            status='SUCCESS',
            recipient=user.email,
            title='Mark All Read',
            message=f"Marked {updated_count} notifications as read."
        )

        return Response({"message": f"{updated_count} notifications marked as read", "count": updated_count})

    @action(detail=False, methods=['post'], url_path='delete-multiple')
    def delete_multiple(self, request):
        """POST /api/notifications/delete-multiple/"""
        ids = request.data.get('ids', [])
        if not ids or not isinstance(ids, list):
            return Response({"detail": "List of 'ids' required."}, status=status.HTTP_400_BAD_REQUEST)

        user = request.user
        if getattr(user, 'role', '') == 'ADMIN' or user.is_staff:
            target_qs = Notification.objects.filter(id__in=ids)
        else:
            target_qs = Notification.objects.filter(id__in=ids, user=user)

        count = target_qs.count()
        target_qs.delete()

        NotificationLog.objects.create(
            user=user,
            channel='IN_APP_DELETE_MULTIPLE',
            status='SUCCESS',
            recipient=user.email,
            title='Delete Multiple Notifications',
            message=f"Deleted {count} notifications."
        )

        return Response({"message": f"{count} notifications deleted", "count": count})

    @action(detail=False, methods=['post'], url_path='mark-multiple-read')
    def mark_multiple_read(self, request):
        """POST /api/notifications/mark-multiple-read/"""
        ids = request.data.get('ids', [])
        if not ids or not isinstance(ids, list):
            return Response({"detail": "List of 'ids' required."}, status=status.HTTP_400_BAD_REQUEST)

        user = request.user
        now = timezone.now()
        if getattr(user, 'role', '') == 'ADMIN' or user.is_staff:
            target_qs = Notification.objects.filter(id__in=ids, is_read=False)
        else:
            target_qs = Notification.objects.filter(id__in=ids, user=user, is_read=False)

        count = target_qs.update(is_read=True, read_time=now)
        return Response({"message": f"{count} notifications marked read", "count": count})

    @action(detail=False, methods=['get'], url_path='guardian')
    def guardian(self, request):
        queryset = Notification.objects.filter(
            user=request.user,
            category='sos'
        ).order_by('-created_at')
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)


# ── Standalone APIViews matching exact requested path structures ─────────────

class UnreadCountAPIView(APIView):
    """GET /api/notifications/count/"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        count = Notification.objects.filter(
            Q(user=user) | Q(user__isnull=True),
            is_read=False
        ).count()
        return Response({"unread_count": count})


class UnreadNotificationsAPIView(APIView):
    """GET /api/notifications/unread/"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        paginator = NotificationPagination()
        qs = Notification.objects.filter(
            Q(user=user) | Q(user__isnull=True),
            is_read=False
        ).order_by('-created_at')
        page = paginator.paginate_queryset(qs, request)
        serializer = NotificationSerializer(page, many=True)
        return paginator.get_paginated_response(serializer.data)


class MarkNotificationReadAPIView(APIView):
    """POST /api/notifications/read/<id>/ or /api/notifications/<id>/read/"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            notification = Notification.objects.get(pk=pk)
        except Notification.DoesNotExist:
            return Response({"detail": "Notification not found."}, status=status.HTTP_404_NOT_FOUND)

        user = request.user
        if not (user.is_staff or getattr(user, 'role', '') == 'ADMIN') and notification.user and notification.user != user:
            return Response({"detail": "You do not have permission to modify this notification."}, status=status.HTTP_403_FORBIDDEN)

        notification.is_read = True
        notification.read_time = timezone.now()
        notification.save(update_fields=['is_read', 'read_time'])

        NotificationLog.objects.create(
            user=user,
            channel='IN_APP_READ',
            status='SUCCESS',
            recipient=user.email,
            title=notification.title,
            message=f"Notification #{notification.id} marked read."
        )

        return Response(NotificationSerializer(notification).data, status=status.HTTP_200_OK)


class MarkAllNotificationsReadAPIView(APIView):
    """POST /api/notifications/read-all/"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        now = timezone.now()
        updated_count = Notification.objects.filter(
            Q(user=user) | Q(user__isnull=True),
            is_read=False
        ).update(is_read=True, read_time=now)

        return Response({"message": f"{updated_count} notifications marked read", "count": updated_count})


class NotificationHistoryAPIView(APIView):
    """GET /api/notifications/history/"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        paginator = NotificationPagination()
        logs = NotificationLog.objects.all().order_by('-created_at')
        if not (request.user.is_staff or getattr(request.user, 'role', '') == 'ADMIN'):
            logs = logs.filter(user=request.user)

        page = paginator.paginate_queryset(logs, request)
        serializer = NotificationLogSerializer(page, many=True)
        return paginator.get_paginated_response(serializer.data)


class FCMDeviceViewSet(viewsets.ModelViewSet):
    queryset = FCMDevice.objects.all()
    serializer_class = FCMDeviceSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        token = serializer.validated_data.get('token')
        FCMDevice.objects.filter(token=token).delete()
        serializer.save(user=self.request.user)


class FCMDeviceRegisterAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        token = request.data.get('token')
        if not token:
            return Response({'detail': 'FCM token is required.'}, status=status.HTTP_400_BAD_REQUEST)

        FCMDevice.objects.filter(token=token).exclude(user=request.user).delete()
        device, created = FCMDevice.objects.update_or_create(
            token=token,
            defaults={'user': request.user}
        )
        return Response(
            FCMDeviceSerializer(device).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK
        )


class NotificationTemplateViewSet(viewsets.ModelViewSet):
    queryset = NotificationTemplate.objects.all().order_by('-created_at')
    serializer_class = NotificationTemplateSerializer
    permission_classes = [permissions.IsAuthenticated]


class NotificationLogViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = NotificationLog.objects.all().order_by('-created_at')
    serializer_class = NotificationLogSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = NotificationPagination

    def get_queryset(self):
        qs = NotificationLog.objects.all().order_by('-created_at')
        if not (self.request.user.is_staff or getattr(self.request.user, 'role', '') == 'ADMIN'):
            qs = qs.filter(user=self.request.user)

        channel = self.request.query_params.get('channel')
        if channel:
            qs = qs.filter(channel__iexact=channel)

        status_param = self.request.query_params.get('status')
        if status_param:
            qs = qs.filter(status__iexact=status_param)

        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(
                Q(recipient__icontains=search) |
                Q(title__icontains=search) |
                Q(message__icontains=search)
            )

        return qs

    @action(detail=True, methods=['post'], url_path='retry')
    def retry(self, request, pk=None):
        """
        Retry dispatching a failed notification log entry.
        """
        log_entry = self.get_object()
        user = log_entry.user
        channel = (log_entry.channel or '').upper()

        log_entry.retry_count += 1
        success = False
        provider_resp = ''
        err_msg = ''

        try:
            from .notification_service import send_push, send_email, SMSService
            if channel == 'FCM' and user:
                success = send_push(user, log_entry.title or 'CareConnect Alert', log_entry.message)
                provider_resp = 'FCM Push Retried'
            elif channel == 'EMAIL':
                success = send_email(log_entry.recipient, log_entry.title or 'CareConnect Alert', log_entry.message, user=user)
                provider_resp = 'Email Retried via SMTP'
            elif channel == 'SMS':
                success = SMSService.send_sms(log_entry.recipient, log_entry.message, user=user)
                provider_resp = 'SMS Retried'
            elif channel == 'IN_APP' and user:
                from .models import Notification
                Notification.objects.create(
                    user=user,
                    title=log_entry.title or 'CareConnect Alert',
                    message=log_entry.message,
                    category='general'
                )
                success = True
                provider_resp = 'In-App Notification Retried'
            else:
                err_msg = f"Unsupported channel or missing recipient for retry: {channel}"
        except Exception as e:
            success = False
            err_msg = str(e)

        if success:
            log_entry.status = 'SUCCESS'
            log_entry.provider_response = provider_resp
            log_entry.error_message = None
            log_entry.failure_reason = None
        else:
            log_entry.status = 'FAILURE'
            log_entry.error_message = err_msg or 'Retry attempt failed'
            log_entry.failure_reason = f"Retry count: {log_entry.retry_count}"

        log_entry.save()

        return Response(
            NotificationLogSerializer(log_entry).data,
            status=status.HTTP_200_OK if success else status.HTTP_400_BAD_REQUEST
        )

    @action(detail=False, methods=['post'], url_path='retry-failed')
    def retry_failed(self, request):
        """
        Retry all failed notification logs.
        """
        failed_logs = NotificationLog.objects.filter(status='FAILURE')
        if not (request.user.is_staff or getattr(request.user, 'role', '') == 'ADMIN'):
            failed_logs = failed_logs.filter(user=request.user)

        success_count = 0
        total = failed_logs.count()

        for log_entry in failed_logs[:50]:  # Limit batch
            user = log_entry.user
            channel = (log_entry.channel or '').upper()
            log_entry.retry_count += 1
            ok = False

            try:
                from .notification_service import send_push, send_email, SMSService
                if channel == 'FCM' and user:
                    ok = send_push(user, log_entry.title or 'CareConnect Alert', log_entry.message)
                elif channel == 'EMAIL':
                    ok = send_email(log_entry.recipient, log_entry.title or 'CareConnect Alert', log_entry.message, user=user)
                elif channel == 'SMS':
                    ok = SMSService.send_sms(log_entry.recipient, log_entry.message, user=user)
            except Exception:
                ok = False

            if ok:
                log_entry.status = 'SUCCESS'
                log_entry.provider_response = 'Batch retry successful'
                log_entry.error_message = None
                log_entry.failure_reason = None
                success_count += 1
            else:
                log_entry.status = 'FAILURE'
                log_entry.failure_reason = f"Batch retry count: {log_entry.retry_count}"
            log_entry.save()

        return Response({
            'message': f"Retried {min(total, 50)} failed notifications",
            'success_count': success_count,
            'total_failed': total
        }, status=status.HTTP_200_OK)


class SMSLogViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = SMSLog.objects.all().order_by('-sent_at')
    serializer_class = SMSLogSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = NotificationPagination


class GuardianNotificationsAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        notifications = Notification.objects.filter(
            user=user,
            category__in=['sos', 'emergency', 'guardian']
        ).order_by('-created_at')[:50]
        return Response(NotificationSerializer(notifications, many=True).data, status=status.HTTP_200_OK)

