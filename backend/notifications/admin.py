from django.contrib import admin
from .models import Notification, FCMDevice, NotificationTemplate, NotificationLog, SMSLog

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('title', 'user', 'category', 'priority', 'is_read', 'created_at')
    list_filter = ('category', 'priority', 'is_read')
    search_fields = ('title', 'message', 'user__email')

@admin.register(FCMDevice)
class FCMDeviceAdmin(admin.ModelAdmin):
    list_display = ('user', 'token', 'created_at')
    search_fields = ('user__email', 'token')

@admin.register(NotificationTemplate)
class NotificationTemplateAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'title_template', 'subject_template', 'created_at', 'updated_at')
    search_fields = ('name', 'category', 'title_template', 'email_template')
    fieldsets = (
        (None, {'fields': ('name', 'category')}),
        ('Push & In-App', {'fields': ('title_template', 'message_template', 'push_template')}),
        ('Email', {'fields': ('subject_template', 'email_template')}),
        ('SMS', {'fields': ('sms_template',)}),
    )

@admin.register(NotificationLog)
class NotificationLogAdmin(admin.ModelAdmin):
    list_display = ('channel', 'recipient', 'status', 'created_at')
    list_filter = ('channel', 'status')
    search_fields = ('recipient', 'title', 'message', 'error_message')

@admin.register(SMSLog)
class SMSLogAdmin(admin.ModelAdmin):
    list_display = ('to_number', 'provider', 'status', 'sent_at')
    list_filter = ('provider', 'status')
    search_fields = ('to_number', 'message', 'error_message')

