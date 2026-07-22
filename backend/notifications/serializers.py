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
            'created_at',
            'priority',
            'location',
            'incident',
            'incident_details',
        ]


from .models import FCMDevice, NotificationTemplate, NotificationLog

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


