"""
sos/permissions.py

Role-based permission classes for the SOS module.
"""

from rest_framework.permissions import BasePermission

# Role constants matching accounts.CustomUser.ROLE_CHOICES
ROLE_ADMIN = "ADMIN"
ROLE_SOCIETY_MANAGER = "SOCIETY_MANAGER"
ROLE_SECURITY = "SECURITY"
ROLE_RESIDENT = "RESIDENT"
ROLE_STAFF = "STAFF"


class IsAdminRole(BasePermission):
    """Full access – only users with role ADMIN."""

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.role == ROLE_ADMIN
        )


class IsSocietyManagerOrAdmin(BasePermission):
    """Society managers and admins may view all incidents and update status."""

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.role in (ROLE_ADMIN, ROLE_SOCIETY_MANAGER)
        )


class IsSecurityRole(BasePermission):
    """Security staff may view and update status of incidents."""

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.role == ROLE_SECURITY
        )


class IsResidentOwner(BasePermission):
    """
    Residents may only read/create their own incidents.
    Object-level: deny access to incidents belonging to another resident.
    """

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        # Only the owning resident (or admin/manager/security) can access
        user = request.user
        if user.role in (ROLE_ADMIN, ROLE_SOCIETY_MANAGER, ROLE_SECURITY):
            return True
        return obj.resident == user


class CanViewSOS(BasePermission):
    """
    Composite read permission:
    - Admin / Society Manager: all incidents
    - Security: all incidents (view + update only)
    - Resident: own incidents only
    """

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        user = request.user
        if user.role in (ROLE_ADMIN, ROLE_SOCIETY_MANAGER, ROLE_SECURITY):
            return True
        return obj.resident == user
