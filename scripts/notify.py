#!/usr/bin/env python3
import socket
import sys
import requests
import json

# 所属项目
PROJECT = 'DRFREST'
# 接口地址
NOTIFY_API_URL = 'http://127.0.0.1:8000/notify/'


def get_instance_info():
    hostname = socket.gethostname()
    ip = socket.gethostbyname(hostname)
    return hostname, ip


def notify(task_name, result, message):
    hostname, ip = get_instance_info()

    if type(result) is bool:
        pass
    elif result == 0 or result == '0':
        result = True
    else:
        result = False

    data = {
        'project': PROJECT,
        'task_name': task_name,
        'instance_name': hostname,
        'instance_ip': ip,
        'result': result,
        'message': message
    }
    resp = requests.post(NOTIFY_API_URL, headers={
        'Accept': 'application/json',
        'Content-Type': 'application/json',
    }, data=json.dumps(data))
    return resp


if __name__ == '__main__':
    try:
        task_name, result = sys.argv[1:2]
    except ValueError:
        print('缺少参数:task_name, result')
        sys.exit(1)
    try:
        message = sys.argv[3]
    except ValueError:
        message = ''

    resp = notify(task_name, result, message)
    print(resp)
