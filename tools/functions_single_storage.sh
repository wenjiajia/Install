#! /bin/bash

export BAK_POSTFIX=".vrv.bak"

function add_grizzly_repo()
{
    report_to_dialog "$title" "Install ubuntu-cloud-keyring..." 3
    force_install ubuntu-cloud-keyring >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install python-software-properties..." 6
    force_install python-software-properties >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install python-keyring..." 9
    force_install python-keyring >> ${LOG_FILE} 2>>${ERR_FILE}
}

function update_system()
{
    report_to_dialog "$title" "System update..." 12
    apt-get update >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "System upgrade." 15
    sleep 1
    report_to_dialog "$title" "System upgrade.." 18
    sleep 1
    report_to_dialog "$title" "System upgrade..." 21
    sleep 1
    report_to_dialog "$title" "System upgrade...." 24
    sleep 1
    report_to_dialog "$title" "System upgrade....." 27
    sleep 1
    report_to_dialog "$title" "System upgrade......" 30
    apt-get -y --force-yes upgrade >> ${LOG_FILE} 2>>${ERR_FILE}
}

function install_dependency()
{
#    force_install rabbitmq-server
    report_to_dialog "$title" "Synchronize system time..." 33
    sleep 1
    ntpdate $control_pri_ip >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Install python-mysqldb..." 36
    force_install python-mysqldb >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Install expect..." 39
    force_install expect >>${LOG_FILE} 2>>${ERR_FILE};
}



function force_install()
{
    apt-get install -y --force-yes $@
}

function install_storage()
{
    report_to_dialog "$title" "Remove iscsitarget..." 41
    sleep 1
    apt-get autoremove --purge --yes iscsitarget >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove iscsitarget-dkms..." 44
    apt-get autoremove --purge --yes iscsitarget-dkms >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install iscsitarget..." 47
    force_install iscsitarget >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install iscsitarget-dkms..." 50
    force_install iscsitarget-dkms >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install lvm..." 53
    force_install lvm2 >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Create devices..." 56
    create_devices >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Setting iscsi configurations..." 59
    iscsi_config >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 2
    report_to_dialog "$title" "Service iscsitarget restart..." 61
    service iscsitarget restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Copy configuration restart..." 64
    sleep 1
    copy_cfg_to_control
}

function copy_cfg_to_control(){
    report_to_dialog "$title" "Sed configuration..." 67
    sleep 1
    sed -i "s/192.168.0.2/$control_node_ip/g" ./tools/storage_login.sh >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Copy storage login shell..." 70
    sleep 1
    scp_wrapper ./tools/storage_login.sh root@$control_pri_ip:/var/storage_login.sh $control_node_root_password >>${LOG_FILE} 2>>${ERR_FILE} 
    sleep 1
    report_to_dialog "$title" "Remove known_hosts..." 73
    rm $HOME/.ssh/known_hosts >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install storage login shell." 77
    sleep 1
    report_to_dialog "$title" "Install storage login shell." 80
    sleep 1
    report_to_dialog "$title" "Install storage login shell." 83
    sleep 1
    report_to_dialog "$title" "Install storage login shell." 86
    sleep 1
    report_to_dialog "$title" "Install storage login shell." 89
    sleep 1
    report_to_dialog "$title" "Install storage login shell." 91
    sleep 1
    report_to_dialog "$title" "Install storage login shell." 94
    ssh_source_wrapper root@$control_pri_ip source /var/storage_login.sh >>${LOG_FILE} 2>>${ERR_FILE}
}

function ssh_source_wrapper(){
    if [ -z "`which expect`" ]; then
	apt-get install -y --force-yes expect >/dev/null
    fi
    expect -c "spawn ssh -oStrictHostKeyChecking=no -oCheckHostIP=no $1 $2 $3
    	set timeout 100
	expect 	\"password\"  
	send \"$control_node_root_password\r\n\" 
        expect eof"
}


function iscsi_config(){
   # sed -i "/service tgt stop/d" /etc/rc.local
   # sed -i "/service iscsitarget restart/d" /etc/rc.local
   # sed -i "/service tgt start/d" /etc/rc.local
   # sed -i "/^exit 0/i\service tgt stop\nservice iscsitarget restart\nservice tgt start\n" /etc/rc.local
    sed -i "s/false/true/g" /etc/default/iscsitarget
    cat <<EOF >/etc/iet/ietd.conf
IncomingUser vrv vrv

#cinder
Target iqn.2013-08.org.jointlab:cinder
Lun 0 Path=/dev/vrv-cloud/lv_cinder,Type=fileio

#glance&instance
Target iqn.2013-08.org.jointlab:glance
Lun 0 Path=/dev/vrv-cloud/lv_glance,Type=fileio
EOF
}
# create devices
function create_devices(){
    partition=`findfs LABEL=vrv-volumes`
    echo $partition > /var/log/partition.sh
    pvcreate $partition
    size=`pvdisplay $partition | sed -n '5p' | awk {'print $3'}`
    size=`printf "%.f" $size`
    glance_size=`expr $size / 3`
    cinder_size=`expr $size - $glance_size`
    temp=`expr $cinder_size % 10`
    cinder_size=`expr $cinder_size - $temp` 
    glance_size="${glance_size}G"
    cinder_size="${cinder_size}G"
    vgcreate vrv-cloud $partition
    lvcreate -L $cinder_size -n lv_cinder vrv-cloud
    lvcreate -L $glance_size -n lv_glance vrv-cloud 
}

function install_monitor(){
    INSDIR=`pwd`
    cd ${INSDIR}/tools/nagios
    . nagios_ins.sh -t
    # FIXME: the control local or remote ip
    if [ -z "`grep -i ${control_pri_ip} /etc/xinetd.d/nrpe`" ]; then
        sed -i "/only_from/{s/$/& ${control_pri_ip}/}" /etc/xinetd.d/nrpe
        service xinetd restart
    fi
    cd ${INSDIR}
}

function add_hosts_storage_in_database(){
    python ./tools/add_hosts.py storage_node
}

