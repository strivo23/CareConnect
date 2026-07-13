from rest_framework import serializers
from .models import Society, BlockTower, Flat

class SocietySerializer(serializers.ModelSerializer):
    total_blocks = serializers.SerializerMethodField(read_only=True)
    total_flats = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = Society
        fields = '__all__'

    def get_total_blocks(self, obj):
        return obj.blocks.count()

    def get_total_flats(self, obj):
        return Flat.objects.filter(block__society=obj).count()

class BlockTowerSerializer(serializers.ModelSerializer):
    society_name = serializers.ReadOnlyField(source='society.name')

    class Meta:
        model = BlockTower
        fields = '__all__'

class FlatSerializer(serializers.ModelSerializer):
    block_name = serializers.ReadOnlyField(source='block.name')
    society_name = serializers.ReadOnlyField(source='block.society.name')
    society_id = serializers.ReadOnlyField(source='block.society.id')

    class Meta:
        model = Flat
        fields = '__all__'
