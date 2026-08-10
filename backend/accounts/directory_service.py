from django.contrib.auth import get_user_model
from django.db.models import Q
from society.models import Society
from emergency.models import Guardian
from accounts.models import UserDirectoryProfile, ResidentProfile

User = get_user_model()


class ContactDirectoryService:
    @staticmethod
    def mask_phone(phone: str) -> str:
        if not phone or len(phone) < 6:
            return "******"
        prefix = phone[:3]
        suffix = phone[-4:]
        return f"{prefix}{'*' * (len(phone) - 7)}{suffix}"

    @staticmethod
    def mask_email(email: str) -> str:
        if not email or "@" not in email:
            return "*****@*****.com"
        username, domain = email.split("@", 1)
        if len(username) <= 2:
            masked_user = username[0] + "*"
        else:
            masked_user = username[0] + "*" * (len(username) - 2) + username[-1]
        return f"{masked_user}@{domain}"

    @classmethod
    def can_view_unmasked(cls, requesting_user, target_user, visibility: str) -> bool:
        if not requesting_user or not requesting_user.is_authenticated:
            return False

        requesting_role = getattr(requesting_user, 'role', 'RESIDENT')
        if requesting_role in ['ADMIN', 'STAFF'] or getattr(requesting_user, 'is_staff', False):
            return True

        if requesting_user.id == target_user.id:
            return True

        if visibility == 'PUBLIC':
            return True

        if visibility == 'RESPONDERS':
            return requesting_role in ['VOLUNTEER', 'SECURITY', 'ADMIN', 'STAFF']

        if visibility == 'GUARDIANS_ONLY':
            # Check if requesting_user is guardian of target_user
            return Guardian.objects.filter(
                resident=target_user,
                phone=getattr(requesting_user, 'phone_number', '')
            ).exists() or Guardian.objects.filter(
                user=requesting_user,
                resident=target_user
            ).exists()

        if visibility == 'PRIVATE':
            return requesting_role in ['ADMIN', 'STAFF']

        return False

    @classmethod
    def get_directory_contacts(cls, requesting_user, filters: dict = None):
        filters = filters or {}
        requesting_role = getattr(requesting_user, 'role', 'RESIDENT')

        qs = User.objects.filter(is_active=True).select_related('resident_profile', 'directory_profile', 'resident_profile__society')

        # Enforce Society Scoping
        if requesting_role not in ['ADMIN', 'STAFF']:
            # Find requesting user's society
            user_society_id = None
            if hasattr(requesting_user, 'resident_profile') and requesting_user.resident_profile and requesting_user.resident_profile.society_id:
                user_society_id = requesting_user.resident_profile.society_id

            if user_society_id:
                qs = qs.filter(resident_profile__society_id=user_society_id)
            else:
                # If no society assigned, return empty unless requesting user is admin
                qs = qs.filter(id=requesting_user.id)
        else:
            # Admin can filter by society
            society_id = filters.get('society')
            if society_id:
                qs = qs.filter(resident_profile__society_id=society_id)

        # Filter by role
        role_filter = filters.get('role')
        if role_filter:
            qs = qs.filter(role=role_filter)

        # Filter by availability
        avail_filter = filters.get('available')
        if avail_filter is not None:
            is_avail = str(avail_filter).lower() in ('true', '1')
            qs = qs.filter(directory_profile__is_available=is_avail)

        # Filter by emergency contact flag
        emerg_filter = filters.get('is_emergency_contact')
        if emerg_filter is not None:
            is_emerg = str(emerg_filter).lower() in ('true', '1')
            qs = qs.filter(directory_profile__is_emergency_contact=is_emerg)

        # Search filter
        search_q = filters.get('search')
        if search_q:
            qs = qs.filter(
                Q(full_name__icontains=search_q) |
                Q(email__icontains=search_q) |
                Q(phone_number__icontains=search_q)
            )

        ordering = filters.get('ordering', 'full_name')
        if ordering in ['full_name', '-full_name', 'role', '-role', 'date_joined', '-date_joined']:
            qs = qs.order_by(ordering)
        else:
            qs = qs.order_by('full_name')

        results = []
        for u in qs:
            dir_prof = getattr(u, 'directory_profile', None)
            visibility = dir_prof.visibility if dir_prof else 'PUBLIC'
            is_unmasked = cls.can_view_unmasked(requesting_user, u, visibility)

            society_name = u.resident_profile.society.name if (hasattr(u, 'resident_profile') and u.resident_profile and u.resident_profile.society) else None
            block_name = u.resident_profile.block.name if (hasattr(u, 'resident_profile') and u.resident_profile and u.resident_profile.block) else None
            photo_url = u.resident_profile.profile_photo.url if (hasattr(u, 'resident_profile') and u.resident_profile and u.resident_profile.profile_photo) else None

            phone_val = u.phone_number if is_unmasked else cls.mask_phone(u.phone_number)

            results.append({
                "id": u.id,
                "name": u.full_name,
                "full_name": u.full_name,
                "role": u.role,
                "society_name": society_name,
                "block_name": block_name,
                "block": block_name,
                "email": u.email if is_unmasked else cls.mask_email(u.email),
                "phone": phone_val if is_unmasked else None,
                "phone_number": phone_val,
                "can_call": is_unmasked and bool(u.phone_number),
                "can_message": True,
                "is_masked": not is_unmasked,
                "visibility": visibility,
                "availability": "online" if getattr(u, 'is_online', True) else ("available" if (dir_prof and dir_prof.is_available) else "offline"),
                "is_available": dir_prof.is_available if dir_prof else True,
                "is_emergency_contact": dir_prof.is_emergency_contact if dir_prof else False,
                "preferred_contact_method": dir_prof.preferred_contact_method if dir_prof else 'PHONE',
                "bio": dir_prof.bio if dir_prof else None,
                "profile_photo": photo_url,
                "is_online": getattr(u, 'is_online', True),
            })

        return results
