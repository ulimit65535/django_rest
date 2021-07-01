#!/bin/bash

# 本地配置
BACKUP_BASE=/var/atlassian/application-data/confluence/backups
RESERVE_DAYS=10
LOG_FILE=/usr/local/src/scripts/remotebackup.log
FILE_SUFFIX=".zip"

# 通知发送,未设置NOTIFY_URL，将不会发送通知
NOTIFY_URL="http://XXX:8000/notify/"
PROJECT_NAME="内部系统"
TASK_NAME="confluence"
INSTANCE_NAME="confluence"

# SSH远程配置,未设置REMOTE_HOST,将不会远程备份
# 若配置REMOTE_PASSWD,需要安装sshpass，否则需要配置ssh互信
REMOTE_HOST=XXX
REMOTE_PORT=22
REMOTE_RESERVE_DAYS=5
REMOTE_USER=XXX
REMOTE_PASSWD=XXX
REMOTE_BACKUP_PATH=/data/confluence

# 执行结果
result="true"
message=""

# 调用远程通知接口
function notify()
{
    curl -X POST -H 'Content-Type: application/json' -d "{\"project\":\"${PROJECT_NAME}\",\"task_name\":\"${TASK_NAME}\",\"instance_name\":\"${INSTANCE_NAME}\",\"result\":${result},\"message\":\"${message}\"}" ${NOTIFY_URL} >> ${LOG_FILE} 2>&1
}

function exit_status()
{
    if [ $? -ne 0 ];then
        message="${message}$1[FAILURE]..."
        result="false"
        notify
        exit 1
    else
        message="${message}$1[SUCCESS]..."
    fi
}

# 检查自动备份文件并远程拷贝
function remote_sync()
{
    last_backups=`find ${BACKUP_BASE}/* -maxdepth 0 -name "*${FILE_SUFFIX}" -type f -mtime -1`
    test -n ${last_backups}
    exit_status "检查备份"
    for backup_file in ${last_backups}
    do
        if [ ${REMOTE_PASSWD} ];then
            sshpass -p "${REMOTE_PASSWD}" rsync -ae "ssh -p ${REMOTE_PORT} -o stricthostkeychecking=no" ${backup_file} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BACKUP_PATH}/
        else
            rsync -ae "ssh -p ${REMOTE_PORT} -o stricthostkeychecking=no" ${backup_file} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BACKUP_PATH}/
        fi
    done
    exit_status "远程拷贝"
}

# 本地清理
function local_clean()
{
    local_clean_files=`find ${BACKUP_BASE}/* -maxdepth 0 -name "*${FILE_SUFFIX}" -type f -mtime +${RESERVE_DAYS}`
    find ${BACKUP_BASE}/* -maxdepth 0 -name "*${FILE_SUFFIX}" -type f -mtime +${RESERVE_DAYS} -exec rm -f {} \;
    exit_status "本地清理"
}

# 远程清理
function remote_clean()
{
    if [ ${REMOTE_PASSWD} ];then
        remote_clean_files=`sshpass -p "${REMOTE_PASSWD}" ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} "find ${REMOTE_BACKUP_PATH}/* -maxdepth 0 -name \"*${FILE_SUFFIX}\" -type f -mtime +${REMOTE_RESERVE_DAYS}"`
        sshpass -p "${REMOTE_PASSWD}" ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} "find ${REMOTE_BACKUP_PATH}/* -maxdepth 0 -name \"*${FILE_SUFFIX}\" -type f -mtime +${REMOTE_RESERVE_DAYS} -exec rm -f {} \;"
    else
        remote_clean_files=`ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} "find ${REMOTE_BACKUP_PATH}/* -maxdepth 0 -name \"*${FILE_SUFFIX}\" -type f -mtime +${REMOTE_RESERVE_DAYS}"`
        ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} "find ${REMOTE_BACKUP_PATH}/* -maxdepth 0 -name \"*${FILE_SUFFIX}\" -type f -mtime +${REMOTE_RESERVE_DAYS} -exec rm -f {} \;"
    fi
    exit_status "远程清理"
}

remote_sync
local_clean
remote_clean

if [ ${NOTIFY_URL} ];then
    notify
else
    # 直接输出到日志
    echo ${result}:${message} >> ${LOG_FILE}
fi

