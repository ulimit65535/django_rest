from django.template.loader import render_to_string
from rest_framework.generics import ListCreateAPIView
from rest_framework.views import APIView
from rest_framework.response import Response
from django.core.mail import EmailMultiAlternatives
from django.conf import settings

from .serializers import CronResultSerializer
from .models import CronResult


class CronResultView(ListCreateAPIView):
    """任务计划详细信息"""
    serializer_class = CronResultSerializer
    queryset = CronResult.objects.all()


class SendEmailView(APIView):
    """发送邮件"""
    def get(self, request):
        crs = CronResult.objects.filter(has_notified=False).order_by('result', 'project')
        data = {'num_success': 0, 'num_fail': 0, 'detail': []}

        for cr in crs:
            if cr.result is True:
                data['num_success'] += 1
            else:
                data['num_fail'] += 1
            serializer = CronResultSerializer(cr)
            data['detail'].append(serializer.data)

        html_body = render_to_string(
            'mail.html',
            {"data": data}
        )
        if data['num_fail'] > 0:
            subject = '请注意:存在执行失败任务!'
        else:
            subject = '定时任务执行报告'

        message = EmailMultiAlternatives(
            subject=subject,
            body='',
            from_email=settings.EMAIL_FROM,
            to=settings.EMAIL_RECEIVERS
        )
        message.attach_alternative(html_body, "text/html")
        message.send(fail_silently=False)

        for cr in crs:
            cr.has_notified = True
            cr.save()

        return Response({'message': '邮件发送成功'})

