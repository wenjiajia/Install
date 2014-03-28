#! /bin/bash

export BAK_POSTFIX=".vrv.bak"
is_control=`which nova-scheduler`

function add_grizzly_repo()
{
    report_to_dialog "$title" "Install ubuntu-cloud-keyring..." 3
    force_install ubuntu-cloud-keyring >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Install python-software-properties..." 6
    force_install python-software-properties >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Install python-keyring..." 9
    force_install python-keyring >>${LOG_FILE} 2>>${ERR_FILE};
}

function update_system()
{
    report_to_dialog "$title" "System update..." 12
    apt-get update >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "System update." 14
    sleep 1
    report_to_dialog "$title" "System update.." 16
    sleep 1
    report_to_dialog "$title" "System update..." 18
    sleep 1
    report_to_dialog "$title" "System update..." 20
    sleep 1
    report_to_dialog "$title" "System update...." 22
    sleep 1
    report_to_dialog "$title" "System update....." 24
    sleep 1
    report_to_dialog "$title" "System update......" 26
    apt-get -y --force-yes upgrade >>${LOG_FILE} 2>>${ERR_FILE};
#    apt-get -y --force-yes dist-upgrade
}

function install_dependency()
{
#    force_install rabbitmq-server
    report_to_dialog "$title" "Synchronize system time..." 28
    ntpdate $control_pri_ip >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Install python-mysqldb." 30
    sleep 1
    report_to_dialog "$title" "Install python-mysqldb..." 32
    force_install python-mysqldb >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Install python-memcache..." 34
    force_install python-memcache >> ${LOG_FILE} 2>>${ERR_FILE}
}


function force_install()
{
    apt-get install -y --force-yes $@
}

function install_cinder()
{
    cp -r ./res/license /usr/lib/python2.7/dist-packages/ >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove virtual disk volume..." 36
    apt-get autoremove --purge --yes cinder-volume >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Remove iscsitarget..." 39
    apt-get autoremove --purge --yes iscsitarget >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Remove iscsitarget-dkms..." 42
    apt-get autoremove --purge --yes iscsitarget-dkms >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Remove virtual disk configurations." 46
    rm -rf /var/lib/cinder >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Remove virtual disk configurations..." 49
    rm -rf /etc/cinder >>${LOG_FILE} 2>>${ERR_FILE};
    control_node_ip=${control_node_ip:-"127.0.0.1"}
    control_pri_ip=${control_pri_ip:-"127.0.0.1"}
    control_sec_ip=${control_sec_ip:-"127.0.0.1"}
    mysql_passwd=${mysql_passwd:-123456}
    report_to_dialog "$title" "Install virtual disk volume..." 52
    force_install cinder-volume >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Install iscsitarget..." 56
    force_install iscsitarget >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Install iscsitarget-dkms..." 59
    force_install iscsitarget-dkms >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Install python-cinderclient..." 62
    force_install python-cinderclient >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Copy virtual disk configurations." 66
    cp -r ./res/cinder/* /usr/share/pyshared/cinder/ >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Copy virtual disk configurations.." 69
    ln -s /usr/share/pyshared/cinder/volume/resource_tracker.py /usr/lib/python2.7/dist-packages/cinder/volume/resource_tracker.py >>${LOG_FILE} 2>>${ERR_FILE};
    #replace using port 3260 from service tgt to ietd
    report_to_dialog "$title" "Copy virtual disk configurations..." 72
    sed -i "/service tgt stop/d" /etc/rc.local >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Copy virtual disk configurations...." 76
    sed -i "/service iscsitarget restart/d" /etc/rc.local >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Copy virtual disk configurations....." 79
    sed -i "/^exit 0/i\service tgt stop\nservice iscsitarget restart\n" /etc/rc.local >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Copy virtual disk configurations......" 82
    sed -i "s/false/true/g" /etc/default/iscsitarget >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Service iscsitarget restart" 86
    service iscsitarget restart >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Copy virtual disk configurations." 89
    echo "service: CommandFilter, /usr/bin/service, root" >> /etc/cinder/rootwrap.d/volume.filters 2>>${ERR_FILE};
    report_to_dialog "$title" "Copy virtual disk configurations.." 90
    cinder_config >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Copy virtual disk configurations..." 92
    local_storage_for_cinder >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Virtual disk service restart.." 94
    service_restart  >>${LOG_FILE} 2>>${ERR_FILE};
}

function cinder_config(){
    cat <<EOF > /etc/cinder/cinder.conf
[DEFAULT]
rootwrap_config=/etc/cinder/rootwrap.conf
sql_connection = mysql://cinder:$mysql_passwd@$control_sec_ip/cinder
api_paste_confg = /etc/cinder/api-paste.ini
iscsi_helper=ietadm
volume_name_template = volume-%s
volume_group = vrv-volumes
verbose = True
auth_strategy = keystone
#osapi_volume_listen_port=5900
my_ip=$control_node_ip
rabbit_host=$control_sec_ip
rabbit_port=5672
memcached_servers=$control_sec_ip:11211
EOF

    cat <<EOF >/etc/cinder/rootwrap.d/volume.filters
# cinder-rootwrap command filters for volume nodes
# This file should be owned by (and only-writeable by) the root user

[Filters]
# cinder/volume/iscsi.py: iscsi_helper '--op' ...
ietadm: CommandFilter, /usr/sbin/ietadm, root
tgtadm: CommandFilter, /usr/sbin/tgtadm, root
tgt-admin: CommandFilter, /usr/sbin/tgt-admin, root
cinder-rtstool: CommandFilter, cinder-rtstool, root

# cinder/volume/driver.py: 'vgs', '--noheadings', '-o', 'name'
vgs: CommandFilter, /sbin/vgs, root

# cinder/volume/driver.py: 'lvcreate', '-L', sizestr, '-n', volume_name,..
# cinder/volume/driver.py: 'lvcreate', '-L', ...
lvcreate: CommandFilter, /sbin/lvcreate, root

# cinder/volume/driver.py: 'dd', 'if=%s' % srcstr, 'of=%s' % deststr,...
dd: CommandFilter, /bin/dd, root

# cinder/volume/driver.py: 'lvremove', '-f', %s/%s % ...
lvremove: CommandFilter, /sbin/lvremove, root

# cinder/volume/driver.py: 'lvdisplay', '--noheading', '-C', '-o', 'Attr',..
lvdisplay: CommandFilter, /sbin/lvdisplay, root

# cinder/volume/driver.py: 'iscsiadm', '-m', 'discovery', '-t',...
# cinder/volume/driver.py: 'iscsiadm', '-m', 'node', '-T', ...
iscsiadm: CommandFilter, /sbin/iscsiadm, root
iscsiadm_usr: CommandFilter, /usr/bin/iscsiadm, root

# cinder/volume/drivers/lvm.py: 'shred', '-n3'
# cinder/volume/drivers/lvm.py: 'shred', '-n0', '-z', '-s%dMiB'
shred: CommandFilter, /usr/bin/shred, root

#cinder/volume/.py: utils.temporary_chown(path, 0), ...
chown: CommandFilter, /bin/chown, root

# cinder/volume/driver.py
dmsetup: CommandFilter, /sbin/dmsetup, root
dmsetup_usr: CommandFilter, /usr/sbin/dmsetup, root
ln: CommandFilter, /bin/ln, root
qemu-img: CommandFilter, /usr/bin/qemu-img, root
env: CommandFilter, /usr/bin/env, root

# cinder/volume/driver.py: utils.read_file_as_root()
cat: CommandFilter, /bin/cat, root

# cinder/volume/nfs.py
stat: CommandFilter, /usr/bin/stat, root
mount: CommandFilter, /bin/mount, root
df: CommandFilter, /bin/df, root
truncate: CommandFilter, /usr/bin/truncate, root
chmod: CommandFilter, /bin/chmod, root
rm: CommandFilter, /bin/rm, root
lvs: CommandFilter, /sbin/lvs, root

# cinder/volume/scality.py
mount: CommandFilter, /bin/mount, root
dd: CommandFilter, /bin/dd, root

service: CommandFilter, /usr/bin/service, root
vgdisplay: CommandFilter, /sbin/vgdisplay, root
EOF
}

function service_restart()
{
    if [ -f /etc/network/interfaces.vrv.bak ];then
	mv /etc/network/interfaces.vrv.bak /etc/network/interfaces   
    fi
    /etc/init.d/networking restart

    service tgt stop
    service iscsitarget restart
    service cinder-volume restart
    service tgt start
}

function local_storage_for_cinder()
{
    #dd if=/dev/zero of=/var/lib/cinder/cinder-volumes bs=1 count=0 seek=128M
    #losetup /dev/loop0 /var/lib/cinder/cinder-volumes
    #pvcreate /dev/loop0
    #vgcreate cinder-volumes /dev/loop0
    partition=`findfs LABEL=vrv-volumes`
    pvcreate ${partition}
    vgcreate vrv-volumes ${partition}
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

