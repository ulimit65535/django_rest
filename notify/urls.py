from django.conf.urls import url
from . import views


urlpatterns = [
    # 获取用户详情
    url(r'^notify/$', views.CronResultView.as_view()),
]