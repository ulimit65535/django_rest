from rest_framework import serializers

from . models import CronResult


class CronResultSerializer(serializers.ModelSerializer):
    """地址标题"""
    class Meta:
        model = CronResult
        fields = '__all__'
        extra_kwargs = {  # 修改字段属性
            'create_time': {
                'read_only': True
            },
            'update_time': {
                'read_only': True
            },
            'has_notified': {
                'read_only': True,
            }
        }



