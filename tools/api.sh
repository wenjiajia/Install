#! /bin/bash


if [ -e ./tools/gui_install.sh ]; then
    source ./tools/gui_install.sh
else
    echo "can't find the file ./tools/gui_install.sh"
    sleep 5
    exit 1
fi

ERR_PERCENT_LOG=./temp.log

# detect local nic and ipv4
function detect_interfaces() {
    local nics=`ip link | grep "<" | egrep -v 'lo' | awk '{print $2}' | awk -F ':' '{print $1}'`
    echo $nics
}

# show all interface_label which has ipv4
function get_all_interface_label() {
    local nics=`detect_interfaces`
    for nic in $nics; do
        if [[ "$nic" =~ "virbr" ]]; then
            continue
        fi
        if [[ "$nic" =~ "vnet" ]]; then
            continue
        fi
        if [[ "$nic" =~ "br-ex" ]]; then
            continue
        fi
	local ipv4=`ifconfig $nic | grep "inet addr" | awk '{print $2}' | awk -F ':' '{print $2}'`
   	if [ -z $ipv4 ];then
	    continue
   	fi
	echo $nic
    done
}

# get interface ipv4 address
function get_interface_ipv4() {
    if [ -z "$1" ]; then
       return $STRING_NULL
    fi
    local ipv4=`ifconfig $1 | grep "inet addr" | awk '{print $2}' | awk -F ':' '{print $2}'`
    echo $ipv4
    if [ -z $ipv4 ];then
	dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Error\Zn" \
	   --msgbox "you must input your inet addr before install" 8 45
	exit 1	
    fi
}

# detect ipv4 whether or not is null
function detect_ipv4_not_null(){
    local nics=`detect_interfaces`
    for nic in $nics; do
	get_interface_ipv4 $nic
    done
}

# show nic and ipv4 address
function show_nic_and_ipv4() {
    local nics=`detect_interfaces`
    for nic in $nics; do
	local ipv4=`ifconfig $nic | grep "inet addr" | awk '{print $2}' | awk -F ':' '{print $2}'`
	echo $nic $ipv4
    done
}

# detect the number of local nics
function detect_nic_numbers() {
    local nics_num=`ip link | grep "<"| egrep -v 'lo' | awk '{print $2}' | awk -F ':' '{print $1}'| grep eth | wc -l ` 
    if [ $nics_num -lt 2 ];then
	echo $ASSERT_NIC_NUMBERS_ERROR >${ERR_PERCENT_LOG}
	return $ASSERT_NIC_NUMBERS_ERROR
    else
	return $ASSERT_SUCCESS
    fi
}

# assert primary nic ipv4 exists
function assert_primary_nic_ipv4_exists() {
    if [ -z "`get_primary_interface_label`" ]; then
	echo $ASSERT_PRINIC_EXIST >${ERR_PERCENT_LOG}
	return $ASSERT_PRINIC_EXIST 
    fi
    nic=`get_primary_interface_label`
    local ipv4=`ifconfig $nic | grep "inet addr" | awk '{print $2}' | awk -F ':' '{print $2}'`
    if [ -z $ipv4 ];then
	echo $ASSERT_PRINIC_EXIST >${ERR_PERCENT_LOG}
	return $ASSERT_PRINIC_EXIST
    fi
    return $ASSERT_SUCCESS
}

# assert secondary nic ipv4 exists
function assert_secondary_nic_ipv4_exists(){
    if [ -z "`get_secondary_interface_label`" ]; then
	echo $ASSERT_SECNIC_EXIST >${ERR_PERCENT_LOG}
	return $ASSERT_SECNIC_EXIST
    else
	return $ASSERT_SUCCESS
    fi
}


# check if this interface is primary according to route table
function is_primary_interface() {
    if [ -z "$1" ]; then
        return $STRING_NULL
    fi
    if [ -z "`route -nn | grep $1 | grep UG`" ]; then
        return $STRING_NULL
    else
        return $PRI_NIC_OK
    fi
}

# get primary interface label
function get_primary_interface_label() {
    local nics=`detect_interfaces`
    for nic in $nics; do
        is_primary_interface $nic
        if [ "$?" -eq "$PRI_NIC_OK" ]; then
            echo $nic
        fi
    done
    return $PRI_NIC_NO
}

# this function will filter virbr and vnet
function get_secondary_interface_label() {
    local nics=`detect_interfaces`
    for nic in $nics; do
        if [[ "$nic" =~ "virbr" ]]; then
            continue
        fi
        if [[ "$nic" =~ "vnet" ]]; then
            continue
        fi
	local ipv4=`ifconfig $nic | grep "inet addr" | awk '{print $2}' | awk -F ':' '{print $2}'`
   	if [ -z $ipv4 ];then
		continue
   	fi
	is_primary_interface $nic
        if [ $? -eq "$STRING_NULL" ]; then
            echo $nic
            return $SEC_NIC_OK
        fi
    done
    return $SEC_NIC_NO
}

# ping control node
function ping_control_node() {
    if [ -z "$1" ]; then
	return $STRING_NULL
    fi
    ping $1 -c 1 > /dev/null
    if [ $? == $PING_ERROR ]; then
	dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Error\Zn" \
	    --msgbox "Failed to ping control node" 8 45 
	exit 1
    fi
}


# ping storage node
function ping_storage_node() {
    if [ -z "$1" ]; then
	return $STRING_NULL
    fi
    ping $1 -c 1 > /dev/null
    if [ $? == $PING_ERROR ]; then
	dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Error\Zn" \
	    --msgbox "Failed to ping storage node" 8 45 
	exit 1
    fi
}
# ping mysql node
function ping_mysql_node() {
    if [ -z "$1" ]; then
	return $STRING_NULL
    fi
    ping $1 -c 1 > /dev/null
    if [ $? == $PING_ERROR ]; then
	dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Error\Zn" \
	    --msgbox "Failed to ping mysql node" 8 45 
	exit 1
    fi
}
# modify network
function modify_network() {
    primary_nic=`get_primary_interface_label`
    primary_nic_ipv4=`get_interface_ipv4 $primary_nic`
    primary_nic_ipv4_pre="${primary_nic_ipv4%\.*}"
    gateway=`get_gateway`
    netmask=`get_netmask $primary_nic`
    network=${primary_nic_ipv4%\.*}".0"
    backup_file "/etc/network/interfaces"
    
cat <<INTERFACESWITHBREX > /etc/network/interfaces.withbrex
auto lo
iface lo inet loopback

auto br-ex
iface br-ex inet static
address $primary_nic_ipv4
netmask $netmask
gateway $gateway
network $network
#dns-nameservers 8.8.8.8

auto $primary_nic
iface $primary_nic inet manual
up ifconfig \$IFACE 0.0.0.0 up
down ifconfig \$IFACE down

auto $second
iface $second inet static
address $control_node_ip
netmask $netmask

INTERFACESWITHBREX
}

# get gateway
function get_gateway() {
    gates=`ip route | grep default | awk '{print $3}'`
    for gate in $gates; do
        if [ -n "$gate" ]; then
            echo $gate
            break
        fi
    done
}
# get netmask
function get_netmask() {
    netmask=`ifconfig $1 | grep "Mask:" | awk -F ':' '{print $4}'`
    echo $netmask
}
# backup file
function backup_file() {
    if [ ! -f "$1""$BAK_POSTFIX" ]; then
        mv $1 "$1""$BAK_POSTFIX"
    fi
}
# assert partition exist
function assert_partition_exist() {
    if [[ -n `dpkg -l | grep lvm2` ]]; then
        if [[ -n `vgdisplay 2>&1 | grep vrv-volumes` ]]; then
            return $ASSERT_SUCCESS
        fi
    fi
    partition=`findfs LABEL=vrv-volumes`
    echo ${partition} >/var/log/partition.sh
    if [[ -z ${partition} ]]; then
	dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Error\Zn" \
	  --msgbox "vrv-volumes : partition doesn't exist" 8 45 
	exit 1
    fi
    export volume_partition=${partition}
}

# assert kvm
function assert_kvm_ok() {
    if [ `egrep -c '(vmx|svm)' /proc/cpuinfo` -eq 0 ]; then
	echo $ASSERT_KVM_ERROR >${ERR_PERCENT_LOG}
	return $ASSERT_KVM_ERROR
    fi
    r=`dmesg | grep -i "kvm: disabled by bios"`
    if [ -n "$r" ]; then
	echo $ASSERT_KVM_ERROR  >${ERR_PERCENT_LOG}
	return $ASSERT_KVM_ERROR  
    fi
	return $ASSERT_SUCCESS
}

# assert server system support
function detect_system_info() {
    os_codename=$(lsb_release -c -s)
    if [ "precise" != "$os_codename" ]; then
	echo $SYSTEM_INFO_ERROR >${ERR_PERCENT_LOG}
	echo $os_codename
	return $SYSTEM_INFO_ERROR
    fi
    bit=`uname -a | awk '{print $12}'`
    if [ "$bit" != "x86_64" ]; then
	echo $SYSTEM_INFO_ERROR >${ERR_PERCENT_LOG}
	echo $bit
	return $SYSTEM_INFO_ERROR
    fi
#    version=`cat /etc/issue | awk '{print $2}'`
#    if [ "$version" != "12.04.2" ];then
#	echo $SYSTEM_INFO_ERROR >${ERR_PERCENT_LOG}
#	echo $version
#	return $SYSTEM_INFO_ERROR
#    fi
}

# assert resources exist
function assert_resources_exist() {
    if [ -e ./tools/depend_files ]; then
	for file in `cat ./tools/depend_files`; do
            if [ ! -f "$file" ]; then
#               echo ${file} >>${ERR_PERCENT_LOG}
	        echo $ASSERT_RES_EXIST_ERROR >${ERR_PERCENT_LOG}
	        echo "can not find" ${file} >>${ERR_FILE}
    	        return $ASSERT_RES_EXIST_ERROR
            fi
        done
    else
        echo "can't find the file ./tools/depend_files"
        exit 1
    fi
    assert_res_exist cinder
    assert_res_exist glance
    assert_res_exist keystone
    assert_res_exist nova
    assert_res_exist quantum
    assert_res_exist creeper_proxy
    assert_res_exist service
    assert_res_exist spice-html5
#    assert_res_exist spice_proxy
}

function assert_res_exist() {
    if [ -e ./res/$1/depend_files ]; then
	for line in `cat ./res/$1/depend_files`; do
	    file=./res/$1/${line:2}
            if [ ! -f "$file" ]; then
#               echo ${file} >>${ERR_PERCENT_LOG}
	        echo $ASSERT_RES_EXIST_ERROR >${ERR_PERCENT_LOG}
	        echo "can not find" ${file} >>${ERR_FILE}
    	        return $ASSERT_RES_EXIST_ERROR
            fi
        done
    else
        echo "can't find the file ./res/$1/depend_files" >> ./res_depend.log
    fi
}

# assert root
function assert_root() {
    if [ `whoami` != "root" ]; then
	echo $ASSERT_ROOT_ERROR >${ERR_PERCENT_LOG}
	return $ASSERT_ROOT_ERROR
    else    
	return $ASSERT_SUCCESS
    fi
}

# make local source
function add_grizzly_source() {
    if [ -e /var/lib/dpkg/lock ]; then
        rm /var/lib/dpkg/lock
    fi
    if [ -e /var/cache/apt/archives/lock ]; then
        rm /var/cache/apt/archives/lock
    fi
    dpkg --configure -a
    if [ -e win.tgz ]; then
        tar xvf win.tgz >>${LOG_FILE} 2>>${ERR_FILE}
    else
        echo "can't find the file win.tgz"
        sleep 5
        exit 1
    fi
    cp debs/* /var/cache/apt/archives/
    olddir=`pwd` 
    cd /etc/apt/
    backup_file "sources.list"
    echo "deb file:/var/cache/apt/ archives/" > /etc/apt/sources.list
    cd "$olddir"
    apt-get update
}

# return to original sources.list
function revert_sources_list (){
if [ -f /etc/apt/sources.list.vrv.bak ]; then
    mv /etc/apt/sources.list.vrv.bak /etc/apt/sources.list
    apt-get update
fi
}

function license_prompt(){
    dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Notice\Zn" \
        --msgbox "Please visit home page to get your authorization" 8 45
}

function node_control(){
    force_install python-memcache  python-mysqldb >>${LOG_FILE} 2>>${ERR_FILE}
    retval=`python ./tools/node_control.py $control_sec_ip $mysql_passwd`
    if [ "$retval" == "no license" ]; then
        dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Notice\Zn" \
            --msgbox "You have no authorization, please visit home page to get your authorization" 8 45
        exit 1
    fi
    if [ "$retval" == "license but more than node number" ]; then
        dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Notice\Zn" \
            --msgbox "Sorry, node number has achieve maximum, \nyou can't continue install" 8 45
        exit 1  
    fi
}
# all_in_one install
function all_in_one_install(){
    source ./tools/functions_all.sh
    dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Single Mode\Zn" --yes-label "Install_Now" --no-label "Back"\
	--yesno "Install all virtual services " 8 45
    result=$?
    case $result in
	0) all_in_one_install_start;;
	1) mode_menu;;
	255) exit;;
    esac
}

function all_in_one_install_start(){
    select_nic
    set_ip_addr
    set_ip_addr_again
    set_admin_token
    set_mysql_passwd
    title="Single Mode Install"
    all_in_one_percent
}

# control node install
function control_install(){
    source ./tools/functions_control.sh
    dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Mode\Zn" --yes-label "Install_Now" --no-label "Back"\
	--yesno "Install all virtual services without virtual compute services" 8 45
    result=$?
    case $result in
	0) control_install_start;;
	1) cascading_mode_menu;;
	255) exit;;
    esac
}

function control_install_start(){
    select_nic
    set_ip_addr
    set_ip_addr_again
    set_admin_token
    set_mysql_passwd
    title="Cascading Mode Control Service Install"
    control_percent
    license_prompt
}

function force_install()
{
    apt-get install -y --force-yes $@
}

# compute node install
function compute_install(){
    source ./tools/functions_compute.sh
    dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Mode\Zn" --yes-label "Install_Now" --no-label "Back"\
	--yesno "Install virtual compute servcies" 8 45
    result=$?
    case $result in
	0) compute_install_start;;
	1) cascading_mode_menu;;
	255) exit;;
    esac
}


function compute_install_start(){
    if [ -z "`which mysql`" ]; then
	force_install mysql-client-core-5.5 >>${LOG_FILE} 2>>${ERR_FILE}
    fi
    select_nic
    control_pri_nic
    control_sec_nic
    ping_control_node ${control_pri_ip}
    ping_control_node ${control_sec_ip}
    input_control_node_root_password
    input_control_node_mysql_password
    node_control
    modify_dns_setting >>${LOG_FILE} 2>>${ERR_FILE}
    compute_percent
}

# all in one multi storage install
function all_in_one_multi_storage_install(){
    source ./tools/functions_all_multi_storage.sh
    dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Mode\Zn" --yes-label "Install_Now" --no-label "Back"\
	--yesno "Install all virtual services without virtual storage servcies" 8 45
    result=$?
    case $result in
	0) all_in_one_multi_storage_install_start;;
	1) cascading_mode_menu;;
	255) exit;;
    esac
}

function all_in_one_multi_storage_install_start(){
    select_nic
    set_ip_addr
    set_ip_addr_again
    set_admin_token
    set_mysql_passwd
    title="Single Mode Multi Storage Install"
    all_in_one_percent
    license_prompt
}

# all in one single storage install
function all_in_one_single_storage_install(){
    source ./tools/functions_all_single_storage.sh
    dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Mode\Zn" --yes-label "Install_Now" --no-label "Back"\
	--yesno "Install virtual services using mounted disks" 8 45
    result=$?
    case $result in
	0) all_in_one_single_storage_install_start;;
	1) cascading_mode_menu;;
	255) exit;;
    esac
}

function all_in_one_single_storage_install_start(){
    select_nic
    set_ip_addr
    set_ip_addr_again
    set_admin_token
    set_mysql_passwd
    title="Single Mode Single Storage Install"
    all_in_one_percent
    license_prompt
}

# control node single storage
function control_node_single_storage_install(){
    source ./tools/functions_control_single_storage.sh
    dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Mode\Zn" --yes-label "Install_Now" --no-label "Back"\
	--yesno "Install virtual services using mounted disks without virtual compute servcies" 8 45
    result=$?
    case $result in
	0) control_node_single_storage_install_start;;
	1) cascading_mode_menu;;
	255) exit;;
    esac
}     

function control_node_single_storage_install_start(){
    select_nic
    set_ip_addr
    set_ip_addr_again
    set_admin_token
    set_mysql_passwd
    title="Cascading Mode Control Single Storage Service Install"
    control_percent
    license_prompt
}     
                           
# control node multi storage
function control_node_multi_storage_install(){
    source ./tools/functions_control_multi_storage.sh
    dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Mode\Zn" --yes-label "Install_Now" --no-label "Back"\
	--yesno "Install all virtual services without virtual storage and virtual compute servcies" 8 45
    result=$?
    case $result in
	0) control_node_multi_storage_install_start;;
	1) cascading_mode_menu;;
	255) exit;;
    esac
}

function control_node_multi_storage_install_start(){
    select_nic
    set_ip_addr
    set_ip_addr_again
    set_admin_token
    set_mysql_passwd
    title="Cascading Mode Control Multi Storage Service Install"
    control_percent
    license_prompt
}

# single storage install
function single_storage_install(){
    source ./tools/functions_single_storage.sh
    dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Mode\Zn" --yes-label "Install_Now" --no-label "Back"\
	--yesno "Install services used to be mounted disks" 8 45
    result=$?
    case $result in
	0) single_storage_install_start;;
	1) storage_mode_menu;;
	255) exit;;
    esac
}

function single_storage_install_start(){
    if [ -z "`which mysql`" ]; then
	force_install mysql-client-core-5.5 >>${LOG_FILE} 2>>${ERR_FILE}
    fi
    select_nic
    control_pri_nic
    control_sec_nic
    ping_control_node ${control_pri_ip}
    ping_control_node ${control_sec_ip}
    echo $mysql_passwd > /tmp/mysql_passwd.log
    echo $control_pri_ip > /var/mysql_nic.ip    
    input_control_node_root_password
    input_control_node_mysql_password
    node_control
    single_storage_percent "Storage Mode Single Storage Install"
}

# multi storage install
function multi_storage_install(){
    source ./tools/functions_multi_storage.sh
    dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Mode\Zn" --yes-label "Install_Now" --no-label "Back"\
	--yesno "Install virtual storage services" 8 45
    result=$?
    case $result in
	0) multi_storage_install_start;;
	1) storage_mode_menu;;
	255) exit;;
    esac
}

function multi_storage_install_start(){
    if [ -z "`which mysql`" ]; then
	force_install mysql-client-core-5.5 >>${LOG_FILE} 2>>${ERR_FILE}
    fi
    select_nic
    control_pri_nic
    control_sec_nic
    ping_control_node ${control_pri_ip}
    ping_control_node ${control_sec_ip}
    echo $mysql_passwd > /tmp/mysql_passwd.log
    echo $control_pri_ip > /var/mysql_nic.ip   
    input_control_node_root_password
    input_control_node_mysql_password
    node_control
    multi_storage_percent "Storage Mode Multi Storage Install"
}
