from rest_framework.generics import ListCreateAPIView
from rest_framework.views import APIView

from .serializers import CronResultSerializer
from .models import CronResult


class CronResultView(ListCreateAPIView):
    """用户详细信息展示"""
    serializer_class = CronResultSerializer
    queryset = CronResult.objects.all()


class SendEmailView(APIView):
    """激活邮箱"""
    def get(self, request):
        # 响应
        pass
