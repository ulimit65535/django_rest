from django.db import models
from django_rest.utils.models import BaseModel


# Create your models here.
class CronResult(BaseModel):
    """接收cron脚本执行结果"""
    task_name = models.CharField(max_length=20, verbose_name='任务名称')
    project = models.CharField(max_length=20, default='默认项目', verbose_name='归属项目')
    instance_ip = models.GenericIPAddressField(verbose_name='实例ip')
    instance_name = models.CharField(max_length=20, verbose_name='实例名称')
    has_notified = models.BooleanField(default=False, verbose_name='是否已通知')
    result = models.BooleanField(blank=False, null=False, verbose_name='执行结果')
    message = models.TextField(max_length=500, default='', verbose_name='日志记录')

    class Meta:
        db_table = 'tb_cron_results'
        verbose_name = '任务执行结果'
        verbose_name_plural = '任务执行结果'
