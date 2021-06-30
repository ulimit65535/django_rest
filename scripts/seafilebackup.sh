#!/bin/bash

# 本地配置
DBUSER="XXX"
DBPASSWD="XXX"
HOST=127.0.0.1
PORT=3306
MY_CNF=/etc/my.cnf
BACKUP_BASE=/data1/backup
RESERVE_DAYS=5
LOG_FILE=/usr/local/src/scripts/seafilebackup.log
DATA_PATH=/data1/seafile-data


# 通知发送,未设置NOTIFY_URL，将不会发送通知
NOTIFY_URL="http://XXX:8000/notify/"
PROJECT_NAME="内部系统"
TASK_NAME="seafile"
INSTANCE_NAME="seafile"

# SSH远程配置,未设置REMOTE_HOST,将不会远程备份
# 若配置REMOTE_PASSWD,需要安装sshpass，否则需要配置ssh互信
REMOTE_HOST=XXX
REMOTE_PORT=22
REMOTE_RESERVE_DAYS=5
REMOTE_USER="XXX"
REMOTE_PASSWD="XXX"
REMOTE_BACKUP_PATH=/data/seafile/mysql
REMOTE_DATA_PATH=/data/seafile/seafile-data

# 备份参数
MYSQLDUMP_PARAMS="--all-databases"

# 中间参数，无需修改
BACKUP_PATH=${BACKUP_BASE}/$(/bin/date +"%Y%m%d")
BACKUP_PATH_DUMP=${BACKUP_PATH}/
DUMP_PARAMS="-u${DBUSER} -p${DBPASSWD} -h ${HOST} -P ${PORT} ${MYSQLDUMP_PARAMS}"


# 执行结果
result="true"
message=""

# 初化始，创建备份目录
function initialize()
{
    ulimit -n 65535
    if [ ! -d ${BACKUP_PATH_DUMP} ]; then mkdir -p ${BACKUP_PATH_DUMP}; fi
}

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

# mysqldump备份
function backup_dump()
{
    mysqldump ${DUMP_PARAMS} 1> ${BACKUP_PATH_DUMP}/dump.sql 2>> ${LOG_FILE}
    exit_status "表结构备份"
}

# 远程拷贝
function remote_sync()
{
    if [ ${REMOTE_PASSWD} ];then
        sshpass -p "${REMOTE_PASSWD}" rsync -ae "ssh -p ${REMOTE_PORT}" ${BACKUP_PATH} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BACKUP_PATH}/
    else
        rsync -ae "ssh -p ${REMOTE_PORT}" ${BACKUP_PATH} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BACKUP_PATH}/
    fi
    exit_status "远程拷贝"
}

# 本地清理
function local_clean()
{
    local_clean_dirs=`find ${BACKUP_BASE}/* -maxdepth 0 -name '20*' -type d -mtime +${RESERVE_DAYS}`
    find ${BACKUP_BASE}/* -maxdepth 0 -name '20*' -type d -mtime +${RESERVE_DAYS} -exec rm -rf {} \;
    exit_status "本地清理:${local_clean_dirs}"
}

# 远程清理
function remote_clean()
{
    if [ ${REMOTE_PASSWD} ];then
        remote_clean_dirs=`sshpass -p "${REMOTE_PASSWD}" ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} "find ${REMOTE_BACKUP_PATH}/* -maxdepth 0 -name '20*' -type d -mtime +${REMOTE_RESERVE_DAYS}"`
        sshpass -p "${REMOTE_PASSWD}" ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} "find ${REMOTE_BACKUP_PATH}/* -maxdepth 0 -name '20*' -type d -mtime +${REMOTE_RESERVE_DAYS} -exec rm -rf {} \;"
    else
        remote_clean_dirs=`ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} "find ${REMOTE_BACKUP_PATH}/* -maxdepth 0 -name '20*' -type d -mtime +${REMOTE_RESERVE_DAYS}"`
        ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} "find ${REMOTE_BACKUP_PATH}/* -maxdepth 0 -name '20*' -type d -mtime +${REMOTE_RESERVE_DAYS} -exec rm -rf {} \;"
    fi
    exit_status "远程清理:${remote_clean_dirs}"
}

function sync_data()
{
    if [ ${REMOTE_PASSWD} ];then
        sshpass -p "${REMOTE_PASSWD}" rsync -ae "ssh -p ${REMOTE_PORT}" ${DATA_PATH} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DATA_PATH}/
    else
        rsync -ae "ssh -p ${REMOTE_PORT}" ${DATA_PATH} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DATA_PATH}/
    fi
    exit_status "数据目录同步"
}


initialize
backup_dump

if [ ${REMOTE_HOST} ];then
    remote_sync
    remote_clean
    sync_data
fi

local_clean

if [ ${NOTIFY_URL} ];then
    notify
else
    # 直接输出到日志
    echo ${result}:${message} >> ${LOG_FILE}
fi

