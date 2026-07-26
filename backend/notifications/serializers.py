from rest_framework import serializers
from .models import Notification
from sos.serializers import SOSIncidentSerializer

class NotificationSerializer(serializers.ModelSerializer):
    incident_details = SOSIncidentSerializer(source='incident', read_only=True)

    class Meta:
        model = Notification
        fields = [
            'id',
            'user',
            'title',
            'message',
            'category',
            'is_read',
            'read_time',
            'created_at',
            'priority',
            'delivery_status',
            'delivery_channel',
            'recipient_role',
            'notification_type',
            'location',
            'incident',
            'incident_details',
        ]



from .models import FCMDevice, NotificationTemplate, NotificationLog, SMSLog

class FCMDeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = FCMDevice
        fields = ['id', 'user', 'token', 'created_at']
        read_only_fields = ['user']


class NotificationTemplateSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationTemplate
        fields = '__all__'


class NotificationLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationLog
        fields = '__all__'


class SMSLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = SMSLog
        fields = '__all__'



