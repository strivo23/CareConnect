from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r"^ws/incidents/(?P<incident_id>\d+)/chat/$", consumers.IncidentChatConsumer.as_asgi()),
]
