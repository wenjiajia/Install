#! /usr/bin/env bash

# Author: Lawrency Meng
# Date: 2013-4-23
# Version: v1.0.0
# Description: the voyage install sh
# NOTE: keystone middleware need when voyage install alone.
#       User and pass of Nagios db cannot change.
#       cloudrc which product by vrvcloud install need.

# dirs cont
TOP_DIR=`pwd`

# voyage cont
VERSION="3.0.0"
SRC_DIR="../../debs/voyage-${VERSION}.tar.gz"
DEPEND="${TOP_DIR}/apt"
UNTAR_TMP="/tmp"
VOYAGE_DIR="${UNTAR_TMP}/voyage-${VERSION}"
PIP_DIR="${TOP_DIR}/pipdir"
SETUP_CFG="${VOYAGE_DIR}/setup.cfg"
TEST_DIR="${TOP_DIR}/tests"

# depend cont
#COULDRC="/root/cloudrc"
ADMIN_TOKEN=${admin_token:-"123456"}

# db cont
DB_USER="nagios"
DB_PASS="nagios"
DB_NAME="nagios"
DB_ROOT_PASS=${mysql_passwd:-123456}

# net cont
HOSTNAME=`hostname`
HOST_IP_IFACE=${HOST_IP_IFACE:-$(ip route | sed -n '/^default/{ s/.*dev \([a-z0-9-]\+\)\s\+.*/\1/; p; }')}
HOSTIP=`LC_ALL=C ip -f inet addr show ${HOST_IP_IFACE} | awk '/inet/ {split($2,parts,"/");  print parts[1]}'`

# check the depends in apt file
function check_depends(){

    while read -r line
    do
        apt-get install -y --force-yes $line
        if [ $? -ne 0 ]; then
            echo "Error with Package $line install..."
            exit 1
        fi
    done < $DEPEND
}

# conf setup.cfg
function setup_cfg(){
    cd $VOYAGE_DIR
    if [[ -w "$SETUP_CFG" && -z "`grep "^[easy_install]$" ${SETUP_CFG}`" ]]; then
        cat <<EASYINSTALL >> ${SETUP_CFG}
[easy_install]
allow_hosts = ''
find_links = file://${TOP_DIR}/pipdir/
EASYINSTALL
    fi
    cd $TOP_DIR
}

# install voyage
function voyage_ins(){
    cd $VOYAGE_DIR
    python setup.py install
    if [ $? -ne 0 ]; then
        echo "Error with setup.py install..."
        exit 1
    else
        echo "[Info] Voyage install successfully..."
    fi
    cd $TOP_DIR
}

# check the untar tmp dir
function check_dir(){
    if [ ! -d ${UNTAR_TMP} ]; then
        mkdir -p ${UNTAR_TMP}
        echo "[Info] Create the untar temp dir ${UNTAR_TMP}"
    fi
}

# configure voyage
function voyage_cfg(){
    cd $VOYAGE_DIR
    cp -r ${VOYAGE_DIR}/etc/voyage /etc/

    # create log dir
    mkdir -p /var/log/voyage

    # init default threshold strategy
    mysql -unagios -pnagios nagios < ${VOYAGE_DIR}/tools/nagios.sql

    mv /etc/voyage/voyage.conf.sample /etc/voyage/voyage.conf

    if [ ! -z "`grep "^sql_connection" /etc/voyage/voyage.conf`" ]; then
        sql_connection="mysql:\/\/${DB_USER}:${DB_PASS}@${HOSTIP}\/${DB_NAME}?charset=utf8"
        sed -i "s/^sql_connection=.*/sql_connection=${sql_connection}/g" /etc/voyage/voyage.conf
    fi

    # conf api-paste.ini
    sed -i "s/^auth_host = .*/auth_host = ${HOSTIP}/g" /etc/voyage/api-paste.ini
    sed -i "s/^admin_tenant_name = .*/admin_tenant_name = admin/g" /etc/voyage/api-paste.ini
    sed -i "s/^admin_user = .*/admin_user = admin/g" /etc/voyage/api-paste.ini
    sed -i "s/^admin_password = .*/admin_password = ${ADMIN_TOKEN}/g" /etc/voyage/api-paste.ini
    sed -i "s/^signing_dir = .*/signing_dir = \/tmp\/keystone-key-voyage/g" /etc/voyage/api-paste.ini
    cd ${TOP_DIR}
}

# set voyage service
function voyage_ser(){
    cd ${VOYAGE_DIR}
    if [ ! -f /etc/init.d/voyage-api ]; then
        cp ${VOYAGE_DIR}/bin/initvoyage /etc/init.d/voyage-api
        update-rc.d voyage-api defaults
    fi
    if [ ! -f /etc/init.d/voyage-monitor ]; then
        cp ${VOYAGE_DIR}/bin/initmonitor /etc/init.d/voyage-monitor
        update-rc.d voyage-monitor defaults
    fi

    # reset connect errors
    mysqladmin -uroot -p${DB_ROOT_PASS} flush-hosts
    service voyage-api restart
    service voyage-monitor restart
    sleep 3
    if [[ -z "`netstat -tnlp | grep 9257`" \
         && -z "`netstat -tnlp | grep 9267`" ]]; then
        echo "[Info] Error with configure voyage..."
        exit 1
    fi
    echo "[Info] Configure voyage successfully..."
    cd ${TOP_DIR}
}

# unittest
function unittest(){
    cd ${TEST_DIR}

    python -m unittest -v testInstall

    cd ${TOP_DIR}
}

function main(){
    check_depends
    check_dir

    tar -xzvf ${TOP_DIR}/${SRC_DIR} -C ${UNTAR_TMP}
    setup_cfg
    voyage_ins
    voyage_cfg
    voyage_ser

    if [ ! -z "$1" ]; then
        if [ "$1" == "-c" ]; then
            unittest
        else
            echo "Please use -c for unittest..."
            exit 1
        fi
    fi
}

main $@
