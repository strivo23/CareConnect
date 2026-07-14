"""
sos/admin.py

Production-quality Django Admin for the SOS module.

Features:
  - Filters (status, category, date)
  - Search (resident name, email, category, message)
  - Date hierarchy
  - Ordering
  - Status colour badges in list display
  - Inline-friendly configuration
"""

from django.contrib import admin
from django.utils.html import format_html
from .models import EmergencyCategory, SOSIncident, SOSEmergencyMessage


# ---------------------------------------------------------------------------
# Status colour map
# ---------------------------------------------------------------------------

STATUS_COLORS = {
    "Pending":     ("#FFA500", "#000"),   # orange
    "Accepted":    ("#1E90FF", "#fff"),   # blue
    "In Progress": ("#9B59B6", "#fff"),   # purple
    "Resolved":    ("#27AE60", "#fff"),   # green
    "Cancelled":   ("#E74C3C", "#fff"),   # red
}


# ---------------------------------------------------------------------------
# EmergencyCategory Admin
# ---------------------------------------------------------------------------

@admin.register(EmergencyCategory)
class EmergencyCategoryAdmin(admin.ModelAdmin):
    list_display  = ("id", "name", "icon", "is_active")
    list_filter   = ("is_active",)
    search_fields = ("name", "description")
    ordering      = ("name",)
    list_editable = ("is_active",)


class SOSEmergencyMessageInline(admin.TabularInline):
    model = SOSEmergencyMessage
    extra = 0
    readonly_fields = ("created_at",)


# ---------------------------------------------------------------------------
# SOSIncident Admin
# ---------------------------------------------------------------------------

@admin.register(SOSIncident)
class SOSIncidentAdmin(admin.ModelAdmin):
    # ── List display ─────────────────────────────────────────────────────────
    list_display = (
        "id",
        "resident",
        "category",
        "priority",
        "colored_status",
        "latitude",
        "longitude",
        "address",
        "created_at",
    )

    # ── Filters ──────────────────────────────────────────────────────────────
    list_filter = (
        "status",
        "priority",
        "category",
        "created_at",
    )

    # ── Search ───────────────────────────────────────────────────────────────
    search_fields = (
        "resident__full_name",
        "resident__email",
        "category__name",
        "message",
        "address",
        "status",
    )

    # ── Ordering ─────────────────────────────────────────────────────────────
    ordering = ("-created_at",)

    # ── Date hierarchy ───────────────────────────────────────────────────────
    date_hierarchy = "created_at"

    # ── Read-only fields ─────────────────────────────────────────────────────
    readonly_fields = ("created_at", "updated_at")

    inlines = [SOSEmergencyMessageInline]

    # ── Field layout ─────────────────────────────────────────────────────────
    fieldsets = (
        ("Incident Info", {
            "fields": ("resident", "category", "status", "priority", "message"),
        }),
        ("Location", {
            "fields": ("latitude", "longitude", "address"),
        }),
        ("Timestamps", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",),
        }),
    )

    # ── Custom column: coloured status badge ─────────────────────────────────
    @admin.display(description="Status", ordering="status")
    def colored_status(self, obj):
        bg, fg = STATUS_COLORS.get(obj.status, ("#999", "#fff"))
        return format_html(
            '<span style="'
            "background:{bg}; color:{fg}; padding:3px 10px; "
            "border-radius:12px; font-weight:600; font-size:0.8em;"
            '">{status}</span>',
            bg=bg,
            fg=fg,
            status=obj.status,
        )


@admin.register(SOSEmergencyMessage)
class SOSEmergencyMessageAdmin(admin.ModelAdmin):
    list_display = ("id", "incident", "sender", "message_snippet", "created_at")
    list_filter = ("created_at",)
    search_fields = ("sender__email", "message", "incident__id")
    ordering = ("-created_at",)

    def message_snippet(self, obj):
        return obj.message[:50] + "..." if len(obj.message) > 50 else obj.message
    message_snippet.short_description = "Message"