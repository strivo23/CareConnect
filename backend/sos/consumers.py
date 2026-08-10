import json
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth import get_user_model
from .models import SOSIncident, IncidentChatMessage
from .services import IncidentChatService

User = get_user_model()


class IncidentChatConsumer(AsyncJsonWebsocketConsumer):
    async def connect(self):
        self.user = self.scope.get("user")
        if not self.user or not self.user.is_authenticated:
            await self.close(code=4001)
            return

        self.incident_id = self.scope["url_route"]["kwargs"]["incident_id"]
        self.room_group_name = f"incident_chat_{self.incident_id}"

        self.incident = await self.get_incident(self.incident_id)
        if not self.incident:
            await self.close(code=4004)
            return

        is_allowed = await database_sync_to_async(IncidentChatService.is_participant)(self.incident, self.user)
        if not is_allowed:
            await self.close(code=4003)
            return

        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )

        await self.accept()

        await self.send_json({
            "type": "connection_established",
            "incident_id": int(self.incident_id),
            "user_id": self.user.id,
            "user_name": getattr(self.user, 'full_name', self.user.email),
            "role": getattr(self.user, 'role', 'RESIDENT'),
            "current_status": self.incident.current_status or self.incident.status,
            "message": "Connected to emergency chat room."
        })

    async def disconnect(self, close_code):
        if hasattr(self, "room_group_name"):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name
            )

    async def receive_json(self, content):
        action = content.get("action") or content.get("type")

        if action in ["ping", "heartbeat"]:
            await self.send_json({"type": "pong"})
            return

        if action == "typing":
            is_typing = content.get("is_typing", True)
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    "type": "chat_typing_broadcast",
                    "user_id": self.user.id,
                    "user_name": getattr(self.user, 'full_name', self.user.email),
                    "is_typing": bool(is_typing)
                }
            )
            return

        if action == "read_receipt":
            last_message_id = content.get("last_message_id")
            if last_message_id:
                await self.mark_read(self.incident_id, self.user, last_message_id)
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        "type": "chat_read_receipt_broadcast",
                        "user_id": self.user.id,
                        "last_message_id": last_message_id
                    }
                )
            return

        if action == "chat_message":
            msg_text = content.get("message", "")
            msg_type = content.get("message_type", "TEXT")
            lat = content.get("latitude")
            lon = content.get("longitude")
            reply_to_id = content.get("reply_to_id")

            try:
                chat_msg = await database_sync_to_async(IncidentChatService.create_chat_message)(
                    incident=self.incident,
                    sender=self.user,
                    message=msg_text,
                    message_type=msg_type,
                    latitude=lat,
                    longitude=lon,
                    reply_to=await self.get_reply_msg(reply_to_id) if reply_to_id else None
                )
                # Success confirmation back to sender
                await self.send_json({
                    "type": "message_delivered_ack",
                    "message_id": chat_msg.id,
                    "status": "DELIVERED"
                })
            except ValueError as val_err:
                await self.send_json({
                    "type": "error",
                    "error": str(val_err)
                })
            except PermissionError as perm_err:
                await self.send_json({
                    "type": "error",
                    "error": str(perm_err)
                })
            except Exception as ex:
                await self.send_json({
                    "type": "error",
                    "error": f"Failed to send message: {ex}"
                })

    async def chat_message_broadcast(self, event):
        await self.send_json({
            "type": "chat_message",
            "message": event["message"]
        })

    async def chat_typing_broadcast(self, event):
        await self.send_json({
            "type": "typing_status",
            "user_id": event["user_id"],
            "user_name": event["user_name"],
            "is_typing": event["is_typing"]
        })

    async def chat_read_receipt_broadcast(self, event):
        await self.send_json({
            "type": "read_receipt",
            "user_id": event["user_id"],
            "last_message_id": event["last_message_id"]
        })

    async def response_update_broadcast(self, event):
        await self.send_json({
            "type": "response_update",
            "update": event["update"]
        })

    @database_sync_to_async
    def get_incident(self, incident_id):
        try:
            return SOSIncident.objects.select_related("resident", "assigned_responder").get(pk=incident_id)
        except SOSIncident.DoesNotExist:
            return None

    @database_sync_to_async
    def get_reply_msg(self, reply_id):
        try:
            return IncidentChatMessage.objects.get(pk=reply_id)
        except IncidentChatMessage.DoesNotExist:
            return None

    @database_sync_to_async
    def mark_read(self, incident_id, user, last_message_id):
        IncidentChatMessage.objects.filter(
            incident_id=incident_id,
            id__lte=last_message_id,
            is_read=False
        ).exclude(sender=user).update(is_read=True)
