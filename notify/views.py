from rest_framework.generics import ListCreateAPIView

from .serializers import CronResultSerializer
from .models import CronResult


class CronResultView(ListCreateAPIView):
    """用户详细信息展示"""
    serializer_class = CronResultSerializer
    queryset = CronResult.objects.all()