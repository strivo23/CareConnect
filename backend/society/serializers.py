from rest_framework import serializers
from .models import Society, BlockTower, Flat

class SocietySerializer(serializers.ModelSerializer):
    total_blocks = serializers.SerializerMethodField(read_only=True)
    total_flats = serializers.SerializerMethodField(read_only=True)
    residents_count = serializers.SerializerMethodField(read_only=True)
    volunteers_count = serializers.SerializerMethodField(read_only=True)
    security_count = serializers.SerializerMethodField(read_only=True)
    society_manager_name = serializers.ReadOnlyField(source='society_manager.full_name', default='')
    society_manager_email = serializers.ReadOnlyField(source='society_manager.email', default='')

    class Meta:
        model = Society
        fields = '__all__'

    def get_total_blocks(self, obj):
        return obj.blocks.count()

    def get_total_flats(self, obj):
        return Flat.objects.filter(block__society=obj).count()

    def get_residents_count(self, obj):
        return obj.residents.count()

    def get_volunteers_count(self, obj):
        return obj.assigned_volunteers.count()

    def get_security_count(self, obj):
        return obj.security_staff.count()


class BlockTowerSerializer(serializers.ModelSerializer):
    society_name = serializers.ReadOnlyField(source='society.name')
    society_code = serializers.ReadOnlyField(source='society.code', default='')
    computed_flats_count = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = BlockTower
        fields = '__all__'

    def get_computed_flats_count(self, obj):
        return obj.flats.count()


class FlatSerializer(serializers.ModelSerializer):
    block_name = serializers.ReadOnlyField(source='block.name')
    society_name = serializers.ReadOnlyField(source='block.society.name')
    society_id = serializers.ReadOnlyField(source='block.society.id')
    owner_name = serializers.SerializerMethodField()
    resident_name = serializers.SerializerMethodField()

    class Meta:
        model = Flat
        fields = '__all__'

    def get_owner_name(self, obj):
        if obj.owner:
            return obj.owner.full_name
        return obj.owner_name or "N/A"

    def get_resident_name(self, obj):
        if obj.resident_user:
            return obj.resident_user.full_name
        return obj.resident_name or "N/A"
