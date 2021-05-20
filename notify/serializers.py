from rest_framework import serializers

from . models import CronResult


class CronResultSerializer(serializers.ModelSerializer):
    """地址标题"""
    class Meta:
        model = CronResult
        fields = '__all__'



