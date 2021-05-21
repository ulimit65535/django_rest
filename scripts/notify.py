#!/usr/bin/env python3
import socket
import sys
import requests
import json

# 接口地址
NOTIFY_API_URL = 'http://127.0.0.1:8000/notify/'


def get_instance_info():
    hostname = socket.gethostname()
    ip = socket.gethostbyname(hostname)
    return hostname, ip


def notify(task_name, hostname=None, ip=None):
    if hostname is None or ip is None:
        hostname, ip = get_instance_info()
    data = {
        'task_name': task_name,
        'instance_name': hostname,
        'instance_ip': ip
    }
    resp = requests.post(NOTIFY_API_URL, headers={
        'Accept': 'application/json',
        'Content-Type': 'application/json',
    }, data=json.dumps(data))
    return resp


if __name__ == '__main__':
    if len(sys.argv) <= 1:
        print('缺少参数:task_name')
        sys.exit(1)
    elif len(sys.argv) == 2:
        task_name = sys.argv[1]
        resp = notify(task_name)
    elif len(sys.argv) == 4:
        task_name = sys.argv[1]
        hostname = sys.argv[2]
        ip = sys.argv[3]
        resp = notify(task_name, hostname, ip)
    else:
        print('参数个数必须为1或3')
        sys.exit(1)

    print(resp)
