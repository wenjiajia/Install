#! /bin/bash

function add_br()
{
    brctl addbr $1
}

function del_br()
{
    brctl delbr $1
}

function reset_br()
{
    for line in `brctl show | awk '{print $1}'`
    do
        if [ "qbr" == "${line:0:3}" ]; then
            del_br $line 
        fi
    done

    del_br br-int
    add_br br-int
}

function reset_vm_state()
{
    mysql_passwd=`grep -r "sql_connection" /etc/nova/nova.conf | awk -F : '{print $3}' | awk -F @ '{print $1}'`
    mysql -unova -p$mysql_passwd -Dnova -e "update instances set vm_state='active' where deleted = 0;"
    service nova-compute restart
}

function restart_vm_by_libvirt()
{
    for vm in `virsh list --all | grep instance | awk '{print $2}'`
    do
        if [ "instance-" == "${vm:0:9}" ]; then
            virsh start $vm > /dev/null
            if [ $? == 0 ]; then
                echo "$vm restart successfully."
            fi
        fi
    done
}

if [ "root" != `whoami` ]; then
    echo "The script only run in root."
    exit
fi

reset_br
reset_vm_state
restart_vm_by_libvirt


