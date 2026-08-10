"""
ASGI config for careconnect project.
Exposes the ASGI callable as a module-level variable named ``application``.
Routing for HTTP and WebSocket requests.
"""

import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "careconnect.settings")
django.setup()

from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from sos.middleware import JwtAuthMiddlewareStack
import sos.routing

django_asgi_app = get_asgi_application()

application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": JwtAuthMiddlewareStack(
        URLRouter(
            sos.routing.websocket_urlpatterns
        )
    ),
})
