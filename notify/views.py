from rest_framework.generics import ListCreateAPIView
from rest_framework.views import APIView
from rest_framework.response import Response

from .serializers import CronResultSerializer
from .models import CronResult


class CronResultView(ListCreateAPIView):
    """用户详细信息展示"""
    serializer_class = CronResultSerializer
    queryset = CronResult.objects.all()


class SendEmailView(APIView):
    """激活邮箱"""
    def get(self, request):
        crs = CronResult.objects.filter(has_notified=False)
        data = {'num_success': 0, 'num_fail': 0, 'detail': []}
        for cr in crs:
            if cr.result is True:
                data['num_success'] += 1
            else:
                data['num_fail'] += 1
            cr.has_notified = True
            cr.save()
        serializer = CronResultSerializer(crs, many=True)
        data['detail'] = serializer.data
        return Response(data)

