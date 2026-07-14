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

