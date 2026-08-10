from urllib.parse import parse_qs
from channels.db import database_sync_to_async
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError

User = get_user_model()


@database_sync_to_async
def get_user_from_jwt(token_string):
    try:
        access_token = AccessToken(token_string)
        user_id = access_token.get("user_id")
        return User.objects.get(id=user_id)
    except (InvalidToken, TokenError, User.DoesNotExist):
        return AnonymousUser()


class JwtAuthMiddleware:
    """
    Custom Channels middleware to authenticate WebSockets using SimpleJWT tokens.
    Token can be supplied in:
    1. Query string parameter: ?token=...
    2. Authorization header: Bearer <token>
    """
    def __init__(self, inner):
        self.inner = inner

    async def __call__(self, scope, receive, send):
        query_string = scope.get("query_string", b"").decode("utf-8")
        query_params = parse_qs(query_string)
        token = query_params.get("token", [None])[0]

        if not token:
            headers = dict(scope.get("headers", []))
            if b"authorization" in headers:
                try:
                    auth_header = headers[b"authorization"].decode("utf-8")
                    if auth_header.startswith("Bearer "):
                        token = auth_header.split(" ")[1]
                except Exception:
                    pass

        if token:
            scope["user"] = await get_user_from_jwt(token)
        else:
            scope["user"] = AnonymousUser()

        return await self.inner(scope, receive, send)


def JwtAuthMiddlewareStack(inner):
    return JwtAuthMiddleware(inner)
