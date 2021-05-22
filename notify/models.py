from django.db import models
from django_rest.utils.models import BaseModel


# Create your models here.
class CronResult(BaseModel):
    """接收cron脚本执行结果"""
    task_name = models.CharField(max_length=20, verbose_name='任务名称')
    instance_ip = models.GenericIPAddressField(verbose_name='实例ip')
    instance_name = models.CharField(max_length=20, verbose_name='实例名称')
    has_notified = models.BooleanField(default=False)
    result = models.BooleanField(blank=False, null=False)
    message = models.TextField(max_length=500, default='')

    class Meta:
        db_table = 'tb_cron_results'
        verbose_name = '任务执行结果'
        verbose_name_plural = '任务执行结果'
