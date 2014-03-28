#! /usr/bin/env bash

# Author: Lawrency Meng
# Date: 2013-3-1
# Version: v1.0.3
# Description: the nagios install sh
# Note: After this shell, this steps should be done.
#       1. Add Controller IP to only_from in /etc/xinetd.d/nrpe.
#          you will find an example at /example/ dir in this tar.gz

# dirs cont
TOP_DIR=`pwd`

#SRC_DIR="${TOP_DIR}/src"
SRC_DIR="${TOP_DIR}/../../debs"
DEPEND="${TOP_DIR}/apt"
SRC_PLUGIN_DIR="${TOP_DIR}/plugin"
ETC_DIR="${TOP_DIR}/etc"
NAGIOS_DIR="/usr/local/nagios/"
UNTAR_TMP="/tmp/nagios/"
PLUGIN_DIR="$NAGIOS_DIR/libexec/"
DEB_DIR="${TOP_DIR}/debs"

# srcs cont
CORE_SRC="nagios-3.4.4.tar.gz"
NRPE_SRC="nrpe-2.14.tar.gz"
PLUGIN_SRC="nagios-plugins-1.4.16.tar.gz"
NDOUTIL_SRC="ndoutils-1.5.2.tar.gz"

# depend cont
COULDRC="/root/cloudrc"

# db cont
DB_USER="nagios"
DB_PASS="nagios"
DB_NAME="nagios"
DB_ROOT_PASS=${mysql_passwd:-123456}

# net cont
HOSTNAME=`hostname`
HOST_IP_IFACE=${HOST_IP_IFACE:-$(ip route | sed -n '/^default/{ s/.*dev \([a-z0-9-]\+\)\s\+.*/\1/; p; }')}
HOSTIP=`LC_ALL=C ip -f inet addr show ${HOST_IP_IFACE} | awk '/inet/ {split($2,parts,"/");  print parts[1]}'`

# control cont
CONTROL_NODE_IP=${CONTROL_NODE_IP:-$control_sec_ip}
CONTROL_NODE_ROOT_PASSWORD=${CONTROL_NODE_ROOT_PASSWORD:-$control_node_root_password}
IS_CONTROL=${IS_CONTROL:-$is_control}

# check the depends in apt file
function check_depends(){

    cat <<POSTFIX | debconf-set-selections
postfix postfix/mailname string ${HOSTNAME}
postfix postfix/main_mailer_type string 'Internet Site'
POSTFIX

    while read -r line
    do
        apt-get install -y --force-yes $line
    done < $DEPEND
}

# check the untar tmp dir
function check_dir(){
    if [ ! -d ${UNTAR_TMP} ]; then
        sudo mkdir -p ${UNTAR_TMP}
        echo "[Info] Create the untar temp dir ${UNTAR_TMP}"
    fi
}


# create users and groups
function create_UG(){
    if [ ! `getent passwd nagios` > /dev/null ]; then
        echo "[Info] Creating a user called nagios..."
        useradd -U -G sudo -s /bin/false -m nagios
        groupadd nagcmd
        usermod -a -G nagcmd www-data
        get_sudo
        cp -r $TOP_DIR /home/nagios/
        chown -R nagios:nagios /home/nagios/
    else
        echo "[Info] user nagios is exist..."
    fi
}

# give sudo priv
function get_sudo(){
    echo "[Info] Giving nagios user passwordless sudo priviledges"
    grep -q "^#includedir.*/etc/sudoers.d" /etc/sudoers ||
        echo "#includedir /etc/sudoers.d" >> /etc/sudoers
        ( umask 226 && echo "nagios ALL=(ALL) NOPASSWD:/sbin/parted" \
             > /etc/sudoers.d/50_nagios_sh )
}

# core install func
function core_install(){
    cd ${SRC_DIR}
    check_dir
    tar -zxvf ${CORE_SRC} -C ${UNTAR_TMP} 1>2 2>/dev/null  && cd ${UNTAR_TMP}/${CORE_SRC%%-*}
    ./configure --with-command-group=nagcmd 1>2 2>/dev/null
    make clean 1>2 2>/dev/null
    make all  1>2 2>/dev/null
    make install 1>2 2>/dev/null
    make install-init 1>2 2>/dev/null
    make install-config 1>2 2>/dev/null
    make install-commandmode 1>2 2>/dev/null

    rm -rf ${NAGIOS_DIR}/etc/*
    cp ${ETC_DIR}/cgi.cfg ${NAGIOS_DIR}/etc/cgi.cfg
    cp ${ETC_DIR}/nagios.cfg ${NAGIOS_DIR}/etc/nagios.cfg
    cp ${ETC_DIR}/ndo2db.cfg ${NAGIOS_DIR}/etc/ndo2db.cfg
    cp ${ETC_DIR}/ndomod.cfg ${NAGIOS_DIR}/etc/ndomod.cfg
    cp ${ETC_DIR}/nrpe.cfg ${NAGIOS_DIR}/etc/nrpe.cfg
    cp ${ETC_DIR}/resource.cfg ${NAGIOS_DIR}/etc/resource.cfg
    cp -r ${ETC_DIR}/objects ${NAGIOS_DIR}/etc/objects
    mv ${NAGIOS_DIR}/etc/objects/hosts/localhost.cfg ${NAGIOS_DIR}/etc/objects/hosts/${HOSTNAME}.cfg
    sed -i "s/localhost/${HOSTNAME}/g" ${NAGIOS_DIR}/etc/objects/hosts/${HOSTNAME}.cfg
    sed -i "s/127.0.0.1/${HOSTIP}/g" ${NAGIOS_DIR}/etc/objects/hosts/${HOSTNAME}.cfg

    chown -R nagios:nagios /usr/local/nagios/

    update-rc.d nagios defaults

    echo "[Info] Install nagios core successfully..."
    cd ${TOP_DIR}
}

function nrpe_install(){
    cd ${SRC_DIR}
    check_dir
    tar -xzvf ${NRPE_SRC} -C ${UNTAR_TMP} 1>2 2>/dev/null && cd ${UNTAR_TMP}/${NRPE_SRC/.tar.gz/}
    ./configure --with-ssl=/usr/lib/openssl --with-ssl-lib=/usr/lib/x86_64-linux-gnu/ --enable-command-args 1>2 2>/dev/null
    make all 1>2 2>/dev/null
    make install-plugin 1>2 2>/dev/null
    make install-daemon 1>2 2>/dev/null
    make install-daemon-config 1>2 2>/dev/null
    make install-xinetd 1>2 2>/dev/null

    cp -r ${ETC_DIR}/nrpe.cfg ${NAGIOS_DIR}/etc/

    if [ -z "`iptables --list | grep 'nrpe'`" ]; then
        iptables -A INPUT -p tcp -m tcp --dport 5666 -j ACCEPT
    fi
    iptables-save > /dev/null
    service xinetd restart
    chown -R nagios:nagios /usr/local/nagios/
    [ ! "`netstat -tnlp | grep 5666 > /dev/null`" ] && echo "[info] Install nagios nrpe successfully..."
    cd ${TOP_DIR}
}

function plugin_install(){
    cd ${SRC_DIR}
    check_dir
    tar -xzvf ${PLUGIN_SRC} -C ${UNTAR_TMP} 1>2 2>/dev/null  && cd ${UNTAR_TMP}/${PLUGIN_SRC/.tar.gz/}
    ./configure --with-nagios-user=nagios --with-nagios-group=nagios 1>2 2>/dev/null
    make 1>2 2>/dev/null
    make install 1>2 2>/dev/null

    cp ${SRC_PLUGIN_DIR}/* ${NAGIOS_DIR}/libexec/

    chmod 755 -R /usr/local/nagios/libexec/*
    [ -d "/usr/local/nagios/libexec" ] && echo "[Info] Install nagios plugin successfully..."
    chown -R nagios:nagios /usr/local/nagios/
    echo "[Info] Nagios plugin default install in dir: /usr/local/nagios/libexec/"
    cd ${TOP_DIR}
}


function ndoutil_install(){
    cd ${SRC_DIR}
    check_dir

    #source $COULDRC
    #DB_ROOT_PASS=${mysql_passwd}

    if [ -z "`grep -i "msgmnb" /etc/sysctl.conf`" ]; then
        echo "kernel.msgmnb=16384000" >> /etc/sysctl.conf
        echo "kernel.msgmni=16384000" >> /etc/sysctl.conf
        sysctl -p
    fi
    tar -xzvf ${NDOUTIL_SRC} -C ${UNTAR_TMP} > /dev/null  && cd ${UNTAR_TMP}/${NDOUTIL_SRC/.tar.gz/}
    ./configure --with-nagios-user=nagios --with-nagios-group=nagios --enable-mysql 1>2 2>/dev/null
    make 1>2 2>/dev/null
    make install 1>2 2>/dev/null
    cp daemon-init /etc/init.d/ndo2db ; chmod 755 /etc/init.d/ndo2db

    # reset connect errors
    mysqladmin -uroot -p${DB_ROOT_PASS} flush-hosts
    # init ndoutils db
    mysql -uroot -p${DB_ROOT_PASS} -e "DROP DATABASE IF EXISTS ${DB_NAME};"
    mysql -uroot -p${DB_ROOT_PASS} -e "CREATE DATABASE ${DB_NAME};"
    mysql -uroot -p${DB_ROOT_PASS} -e "grant all privileges on ${DB_NAME}.* to '${DB_USER}'@'%' identified by '${DB_PASS}';"
    mysql -uroot -p${DB_ROOT_PASS} -e "FLUSH PRIVILEGES;"
    mysql -uroot -p${DB_ROOT_PASS} -e "use ${DB_NAME};source ${UNTAR_TMP}/${NDOUTIL_SRC/.tar.gz/}/db/mysql.sql;"

    cp ${ETC_DIR}/ndo2db.cfg ${ETC_DIR}/ndomod.cfg ${NAGIOS_DIR}/etc/
    # setting db info in dbo2db.cfg
    sed -i "s/db_host=localhost/db_host=${HOSTIP}/g" ${NAGIOS_DIR}/etc/ndo2db.cfg
    sed -i "s/db_name=nagios/db_name=${DB_NAME}/g" ${NAGIOS_DIR}/etc/ndo2db.cfg
    sed -i "s/db_user=nagios/db_user=${DB_USER}/g" ${NAGIOS_DIR}/etc/ndo2db.cfg
    sed -i "s/db_pass=nagios/db_pass=${DB_PASS}/g" ${NAGIOS_DIR}/etc/ndo2db.cfg

    if [ -z  "`grep -e '^broker_module' ${NAGIOS_DIR}/etc/nagios.cfg`" ]; then
        echo "broker_module=/usr/local/nagios/bin/ndomod.o config_file=/usr/local/nagios/etc/ndomod.cfg" >> ${NAGIOS_DIR}/etc/nagios.cfg
    fi

    if [ -e "${NAGIOS_DIR}/var/ndo2db.sock" ]; then
        rm ${NAGIOS_DIR}/var/ndo2db.sock
    fi
    # chown cfg files
    chown -R nagios:nagios ${NAGIOS_DIR}

    update-rc.d ndo2db defaults

    /etc/init.d/ndo2db restart
    /etc/init.d/nagios restart

    if [ ! -z  "`grep -e 'ndomod: Successfully connected to data sink.' ${NAGIOS_DIR}/var/nagios.log`" ]; then
        echo "[info] Install nagios ndoutils successfully..."
        cd ${TOP_DIR}
    fi

}

function get_control_ip_password(){
    clear
    while [ 1 ]
    do
        read -p "input control node ip: " CONTROL_NODE_IP
        is_valid_ipv4 $CONTROL_NODE_IP
        if [ $? -eq 0 ]; then
            break
        fi
    done
    read -p "input control node root's password: " CONTROL_NODE_ROOT_PASSWORD
}

# validate ipv4
function is_valid_ipv4() {
    r=`echo $1 | egrep '^[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}$'`
    if [ -z "$r" ]; then
        echo "ip format is invalid: ""$1"
        return 1
    fi
    return 0
}

# copy compute.cfg to control
function copy_computecfg_to_control_via_expect() {
    expect -c "
        set timeout 30;
        spawn scp -o StrictHostKeyChecking=no ${NAGIOS_DIR}/etc/objects/hosts/${HOSTNAME}.cfg root@$CONTROL_NODE_IP:${NAGIOS_DIR}/etc/objects/hosts/${HOSTNAME}.cfg
        expect {
                    *assword:* {send -- $CONTROL_NODE_ROOT_PASSWORD\r;
                                 expect {
                                    *denied* {exit 2;}
                                    eof
                                 }
                    }
                    eof         {exit 1;}
                }
              "
}

# copy compute.cfg to control
function ssh_control_restart_service() {
    expect -c "set timeout -1;
               spawn ssh -o StrictHostKeyChecking=no root@$CONTROL_NODE_IP $1
               expect {
                    *assword:* {send -- $CONTROL_NODE_ROOT_PASSWORD\r;
                                 expect {
                                    *denied* {exit 2;}
                                    eof
                                 }
                    }
                    eof         {exit 1;}
                }
                "
}

# Setting compute cfg
function setComputeCfg(){

    mkdir -p ${NAGIOS_DIR}/etc/objects/hosts
    cp ${ETC_DIR}/objects/hosts/localhost.cfg ${NAGIOS_DIR}/etc/objects/hosts/${HOSTNAME}.cfg
    sed -i "s/localhost/${HOSTNAME}/g" ${NAGIOS_DIR}/etc/objects/hosts/${HOSTNAME}.cfg
    sed -i "s/127.0.0.1/${HOSTIP}/g" ${NAGIOS_DIR}/etc/objects/hosts/${HOSTNAME}.cfg

    IS_CONTROL=${IS_CONTROL:-`which nova-scheduler`}

    if [ -z "$IS_CONTROL" ]; then
        # FIXME: control_node_ip exist?
        if [ -z "$CONTROL_NODE_ROOT_PASSWORD" ]; then
            get_control_ip_password
        fi

        copy_computecfg_to_control_via_expect
        ssh_control_restart_service "/etc/init.d/ndo2db restart"
        ssh_control_restart_service "/etc/init.d/nagios restart"
    else
        /etc/init.d/ndo2db restart
        /etc/init.d/nagios restart
    fi
}

# controll install
# desc: install nagios core & plugin
function controllIns(){
    core_install
    plugin_install
    ndoutil_install
    nrpe_install
}

# compute install
# desc: install nagios plugin & nrpe
function computeIns(){
    plugin_install
    nrpe_install
    setComputeCfg
}

function show_help(){
    echo "$0 -c | -t | -h"
    echo
    echo "This install shell is used to install nagios at controll or compute node."
    echo
    echo "  -c  install nagios at controll"
    echo "  -t  install nagios at compute"
    echo
    echo " example: $0 -c | -t | -h"

}

function main(){
    [ $# = 0 ] && show_help && exit 1
    check_depends
    create_UG

    while [ ! -z "$1" ]; do
        case $1 in
        -c)     shift; controllIns  ;;
        -t)     shift; computeIns ;;
        -h)     show_help; exit 1 ;;
        esac
        shift
    done
}

main $@
