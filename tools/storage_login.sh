#! /bin/bash

LOG_DIR="/var/log/vrv/cloud"
LOG_FILE="$LOG_DIR"/stdout.log
ERR_FILE="$LOG_DIR"/stderr.log

function set_rc_local(){
    cat <<EOF > /etc/rc.local
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.
service tgt stop
service iscsitarget restart
service iscsi-network-interface restart
service tgt start
iscsiadm -m discovery -t sendtargets -p 192.168.0.2:3260
iscsiadm -m node -T iqn.2013-08.org.jointlab:cinder -p 192.168.0.2:3260 --login
disk_cinder=\`fdisk -l | grep /dev/ | awk END'{print $2}' | awk -F":" '{print $1}'\`
cat \$disk_cinder > /var/log/disk_cinder
iscsiadm -m node -T iqn.2013-08.org.jointlab:glance -p 192.168.0.2:3260 --login
disk_glance=\`fdisk -l | grep /dev/ | awk END'{print \$2}' | awk -F":" '{print \$1}'\`
mount \$disk_glance /mnt/storage
exit 0
EOF
}

function login_storage(){
    iscsiadm -m discovery -t sendtargets -p 192.168.0.2:3260
    iscsiadm -m node -T iqn.2013-08.org.jointlab:cinder -p 192.168.0.2:3260 --login
    disk_cinder=`fdisk -l | grep /dev/ | awk END'{print $2}' | awk -F":" '{print $1}'`
    echo $disk_cinder > /var/log/disk_cinder
    iscsiadm -m node -T iqn.2013-08.org.jointlab:glance -p 192.168.0.2:3260 --login
    disk_glance=`fdisk -l | grep /dev/ | awk END'{print $2}' | awk -F":" '{print $1}'`
    expect -c "spawn mkfs.ext4 $disk_glance
    set timeout 100
    expect \"anyway\"
    send \"y\n\"
    expect eof"
    mkdir /mnt/storage
    mount $disk_glance /mnt/storage 
    mkdir /mnt/storage/images
    mkdir /mnt/storage/instances
    chmod -R a+rwx /mnt/storage
    pvcreate $disk_cinder
    vgcreate vrv-volumes $disk_cinder
}

function upload_images()
{
    cd /var
    source /etc/profile.d/openstack.sh
    if [[ -d img ]]; then
        for i in $( ls img | grep "\.img" )
        do
            glance --os-tenant-name service --os-username glance image-create \
                --name ${i%\.*} --is-public true --container-format ovf --min-disk 15 --min-ram 512\
                --disk-format qcow2 < "img/$i"
        done
    fi
}

set_rc_local >> ${LOG_FILE} 2>>${ERR_FILE}
login_storage  >> ${LOG_FILE} 2>>${ERR_FILE}
upload_images >> ${LOG_FILE} 2>>${ERR_FILE}
