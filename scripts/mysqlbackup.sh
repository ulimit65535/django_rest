#!/bin/bash

# 本地配置
DBUSER="XXX"
DBPASSWD="XXX"
HOST=XXX
PORT=3306
MY_CNF=/etc/my.cnf
BACKUP_BASE=/data1/backup
RESERVE_DAYS=1
#LOG_FILE=/dev/null
LOG_FILE=/usr/local/src/scripts/mysqlbackup.log

# 通知发送,未设置NOTIFY_URL，将不会发送通知
NOTIFY_URL="http://XXX:8000/notify/"
PROJECT_NAME="XXX"
TASK_NAME="mysql"
INSTANCE_NAME="XXX"

# SSH远程配置,未设置REMOTE_HOST,将不会远程备份
# 若配置REMOTE_PASSWD,需要安装sshpass，否则需要配置ssh互信
REMOTE_HOST=XXX
REMOTE_PORT=22
REMOTE_RESERVE_DAYS=3
REMOTE_USER="XXX"
REMOTE_PASSWD="XXX"
REMOTE_BACKUP_PATH=/data/mysqlbackup/XXX/

# 备份参数
# -d:仅进行表结构备份
MYSQLDUMP_PARAMS="--all-databases -d --single-transaction --set-gtid-purged=OFF"
# --galera-info:该选项表示生成了包含创建备份时候本地节点状态的文件xtrabackup_galera_info文件，该选项只适用于备份PXC。
# --stream:该选项表示流式备份的格式，backup完成之后以指定格式到STDOUT，目前只支持tar和xbstream。流式备份。
# 对于服务器上空间不足，或是搭建主从，直接使用流式备份大大简化了备份后的压缩复制所带来的更多开销。
# --no-timestamp:该选项可以表示不要创建一个时间戳目录来存储备份，指定到自己想要的备份文件夹。
# --parallel:xtarbackup子进程将用于同时备份文件的并发数。如果有多个.ibd文件可以并行，如果只有一个表空间文件，则该选项无效
# --compress:该选项表示压缩innodb数据文件的备份
# --extra-lsndir:参数生产checkpoints文件
INNOBACKUP_PARAMS="--compress --compress-threads=4 --parallel=4 --no-timestamp --stream=xbstream"

# 中间参数，无需修改
BACKUP_PATH=${BACKUP_BASE}/$(/bin/date +"%Y%m%d")
BACKUP_PATH_DUMP=${BACKUP_PATH}/${DUMP}
BACKUP_PATH_INCR=${BACKUP_PATH}/${INCR}
BACKUP_PATH_FULL=${BACKUP_PATH}/${FULL}
DUMP_PARAMS="-u${DBUSER} -p${DBPASSWD} -h ${HOST} -P ${PORT} ${MYSQLDUMP_PARAMS}"
FULL_PARAMS="--defaults-file=${MY_CNF} --host=${HOST} --user=${DBUSER} --password=${DBPASSWD} --port=${PORT} ${INNOBACKUP_PARAMS} --extra-lsndir=${BACKUP_PATH_FULL} ${BACKUP_PATH_FULL}"
INCR_PARAMS="--defaults-file=${MY_CNF} --host=${HOST} --user=${DBUSER} --password=${DBPASSWD} --port=${PORT} ${INNOBACKUP_PARAMS} --incremental --extra-lsndir=${BACKUP_PATH_FULL} ${BACKUP_PATH_INCR} --incremental-basedir=${BACKUP_PATH_FULL}"


# 执行结果
result="true"
message=""

function usage()
{
    echo "Usage: `basename $0` options (-f FULL|-i INCR|-d DUMP)"    
    exit 1
}

# 初化始，创建备份目录
function initialize()
{
    ulimit -n 65535
    if [ ! -d ${BACKUP_PATH_DUMP} ]; then mkdir -p ${BACKUP_PATH_DUMP}; fi
    if [ ! -d ${BACKUP_PATH_INCR} ]; then mkdir -p ${BACKUP_PATH_INCR}; fi
    if [ ! -d ${BACKUP_PATH_FULL} ]; then mkdir -p ${BACKUP_PATH_FULL}; fi
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

# innobackupex 全量备份
function backup_full()
{
    innobackupex ${FULL_PARAMS} 1> ${BACKUP_PATH_FULL}/full.xbstream 2>> ${LOG_FILE}
    exit_status "全量备份"
}

# 增量备份
function backup_incr()
{
    innobackupex ${INCR_PARAMS} 1> ${BACKUP_PATH_INCR}/incr.xbstream 2>> ${LOG_FILE}
    exit_status "增量备份"
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

if [ $# -eq 0 ];then
    usage
else
    initialize    
fi

while [ $# -gt 0 ];do
    case "$1" in
    -full | -f ) 
        TASK_NAME=${TASK_NAME}_全量
        backup_full
    ;;
    -incremetal | -i )
        TASK_NAME=${TASK_NAME}_增量
        backup_incr
    ;;
    -dump | -d )
        TASK_NAME=${TASK_NAME}_表结构
        backup_dump
    ;;
    * )
        usage
    ;;
    esac
    shift
done

if [ ${REMOTE_HOST} ];then
    remote_sync
    remote_clean
fi

local_clean

if [ ${NOTIFY_URL} ];then
    notify
else
    # 直接输出到日志
    echo ${result}:${message} >> ${LOG_FILE}
fi

