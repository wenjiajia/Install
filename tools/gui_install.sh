#! /bin/bash

mysql_passwd=${mysql_passwd:-123456}
admin_token=${admin_passwd:-123456}
ext_nic_ip=${ext_nic_ip:-192.168.0.2}
control_node_ip=${control_node_ip:-10.0.1.20}
control_pri_ip=${control_pri_ip:-192.168.0.2}
control_sec_ip=${control_sec_ip:-10.0.1.21}
default_ext_net_cidr=${ext_nic_ip%\.*}
default_manage_forward_ip=${control_node_ip%\.*}
start_ip_addr=${start_ip_addr:-$default_ext_net_cidr.224}
end_ip_addr=${end_ip_addr:-$default_ext_net_cidr.254}
ext_gateway=${ext_gateway:-$default_ext_net_cidr.1}
control_node_root_password=${control_node_root_password:-123456}
default_passwd="123456"
LOG_DIR="/var/log/vrv/cloud"
LOG_FILE="$LOG_DIR"/stdout.log
ERR_FILE="$LOG_DIR"/stderr.log
ERR_PERCENT_LOG=./temp.log
BACKTITLE="VRVCLOUD 3.1.3 INSTALL"

sudo mkdir -p $LOG_DIR

# select nic
function select_nic(){
    all=`get_all_interface_label`
    nics=()
    ipv4s=()
    i=0	
    HHH=""
    GGG=""
    for nic in $all; do
	nics[i]=$nic
	ipv4=`ifconfig $nic | grep "inet addr" | awk '{print $2}' | awk -F ':' '{print $2}'`
	ipv4s[i]=$ipv4
	i=$[$i+1]
    done
    len=${#nics[@]}
    for((i=0;i<$len;i++)); do 
	HHH=$HHH$i' '${nics[$i]}:${ipv4s[$i]}$' '
    done
    dialog --no-shadow --backtitle "$BACKTITLE" --title "Select primary nic" --cancel-label "Quit"\
	--menu "Move using [UP] [DOWN], [Enter] to select" 10 50 10\
	$HHH 2> /tmp/dialog.out
    if [ ${?} != 0 ]; then rm /tmp/dialog.out; exit; fi
    first_num=$(cat /tmp/dialog.out)
    ext_nic_ip=${ipv4s[$first_num]}
    first=${nics[$first_num]}
    unset nics[$first_num]
    unset ipv4s[$first_num]
    for((i=0;i<$len;i++)); do
        if [ "${nics[$i]}" != "" -a "${ipv4s[$i]}" != "" ];then
        GGG=$GGG$i' '${nics[$i]}:${ipv4s[$i]}$' '
        fi
    done
    dialog --no-shadow --backtitle "$BACKTITLE" --title "Select second nic" --cancel-label "Back"\
        --menu "Move using [UP] [DOWN], [Enter] to select. Using [Esc] to quit " 10 50 10\
        $GGG 2> /tmp/dialog.out
    if [ ${?} != 0 ]; then rm /tmp/dialog.out; select_nic; fi
    second_num=$(cat /tmp/dialog.out)
    control_node_ip=${ipv4s[$second_num]}
    second=${nics[$second_num]}
    echo "Primary nic:" "$first $ext_nic_ip" > /tmp/show.log
    echo "Second nic :" "$second $control_node_ip" >> /tmp/show.log
    dialog --no-shadow --backtitle "$BACKTITLE" --title "Confirm your selection" --extra-button --extra-label "Back"\
        --textbox /tmp/show.log 10 45
        case $? in
            3) select_nic;;
            255) exit;;
        esac
}

# set external network range and gateway
function set_ip_addr(){
    dialog --no-shadow --cancel-label "Quit" --form "Config the range of external network" 10 50 0\
    "Start  :" 1 1 "$start_ip_addr" 1 15 15 0 \
    "End    :" 2 1 "$end_ip_addr" 2 15 15 0 \
    "Gateway:" 3 1 "$ext_gateway" 3 15 15 0 2> /tmp/ip.log
    result=$?
    case $result in
        0) 
	    start_ip_addr=`sed -n '1p' /tmp/ip.log`
	    end_ip_addr=`sed -n '2p' /tmp/ip.log`
	    ext_gateway=`sed -n '3p' /tmp/ip.log`
	    is_valid_ip ${start_ip_addr} 
	    if [ "$?"  == "$IP_VALID" ]; then 
		start_ip_addr=${start_ip_addr}
	    else
		set_ip_addr
	    fi 
	    is_valid_ip ${end_ip_addr} 
	    if [ "$?"  == "$IP_VALID" ]; then 
		end_ip_addr=${end_ip_addr}
	    else
		set_ip_addr
	    fi
	    is_valid_ip ${ext_gateway} 
	    if [ "$?"  == "$IP_VALID" ]; then 
		ext_gateway=${ext_gateway}
	    else
		set_ip_addr
	    fi
	    default_ext_net_cidr=${ext_nic_ip%\.*}
	    real_ext_start_ip=${start_ip_addr%\.*}
	    if [ "$default_ext_net_cidr" != "$real_ext_start_ip" ]; then
	        dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Error\Zn" \
	    	--msgbox "Sorry, your starting configrations are wrong!\nPlease enter again" 8 45
	    	set_ip_addr
	    fi
	    real_ext_end_ip=${end_ip_addr%\.*}
	    if [ "$default_ext_net_cidr" != "$real_ext_end_ip" ]; then
	        dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Error\Zn" \
	    	--msgbox "Sorry, your ending configrations are wrong!\nPlease enter again" 8 45
	    set_ip_addr
	    fi
	    a=${start_ip_addr##*\.}
	    fir_ip_last=${a%\/*}
	    b=${end_ip_addr##*\.}
	    last_ip_last=${b%\/*}
	    if [ "$fir_ip_last" -gt "$last_ip_last" -o "$last_ip_last" -ge "255" ]; then
		dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Error\Zn" \
		--msgbox "Sorry, your range configrations are wrong!\nPlease enter again" 8 45
	    set_ip_addr
	    fi;;
	1) exit;;
	255) exit;;
    esac 
}

# set external network range and gateway again
function set_ip_addr_again(){
    dialog --no-shadow --cancel-label "Back" --form "Config the range of external network again" 10 50 0 \
    "Start  :" 1 1 "$start_ip_addr" 1 15 15 0 \
    "End    :" 2 1 "$end_ip_addr" 2 15 15 0 \
    "Gateway:" 3 1 "$ext_gateway" 3 15 15 0 2> /tmp/ip_again.sh
    result=$?
    case $result in
	0) 
	start_ip_addr_again=`sed -n '1p' /tmp/ip_again.sh`
	end_ip_addr_again=`sed -n '2p' /tmp/ip_again.sh`
	ext_gateway_again=`sed -n '3p' /tmp/ip_again.sh`
	jude_start_ip_addr $start_ip_addr_again $start_ip_addr
	jude_end_ip_addr $end_ip_addr_again $end_ip_addr
	jude_ext_gateway $ext_gateway_again $ext_gateway;;
	1) set_ip_addr;;
	255) exit;;
    esac
}

function jude_start_ip_addr(){
    if [ "$1" == "$2" ]; then
	if [ -z "$1" ]; then
	    start_ip_addr=${start_ip_addr}
	fi
    else
	dialog --no-shadow --backtitle "$BACKTITLE" --title "Start ip address!" \
	    --msgbox "Sorry, start ip address don't match!\nPlease enter again!" 8 45
	set_ip_addr
    fi
}

function jude_end_ip_addr(){
    if [ "$1" == "$2" ]; then
	if [ -z "$1" ]; then
	    end_ip_addr=${end_ip_addr}
	fi
    else
	dialog --no-shadow --backtitle "$BACKTITLE" --title "End ip address!" \
	    --msgbox "Sorry, end ip address don't match!\nPlease enter again!" 8 45
	set_ip_addr
    fi
}

function jude_ext_gateway(){
    if [ "$1" == "$2" ]; then
	if [ -z "$1" ]; then
	    ext_gateway=${ext_gateway}
	fi
    else
	dialog --no-shadow --backtitle "$BACKTITLE" --title "Gateway address!" \
	    --msgbox "Sorry, gateway address don't match!\nPlease enter again!" 8 45
	set_ip_addr
    fi
}

# set admin token
function set_admin_token(){
    dialog --no-shadow --backtitle "$BACKTITLE" --title "Please input your admin token" --cancel-label "Quit"\
	--inputbox "Enter your token" 8 50 $admin_token 2>/var/admin.pwd
    result=$?
    case $result in
	0) admin_token=$(cat /var/admin.pwd)
	    if [ -z $admin_token ]; then
		dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Password error\Zn" \
		--msgbox "Input can not be empty" 10 30
		set_admin_token
	    else
		set_admin_token_again
    	    fi;;
	1) exit;;
	255) exit;;
    esac 
}

# set admin token again
function set_admin_token_again(){
    dialog --no-shadow --backtitle "$BACKTITLE" --title "Please input your admin token again" --cancel-label "Back"\
	--inputbox "Enter your token again" 8 50 $admin_token 2>/var/admin.pwd
    result=$?
    pwd_again=$(cat /var/admin.pwd)
    case $result in
	0) jude_admin_token $pwd_again $admin_token;;
	1) set_admin_token;;
	255) exit;;
    esac
}

# jude two admin tokens are same
# param: $1, pwd_again
# param: $2, admin_token
function jude_admin_token(){
    if [ "$1" == "$2" ]; then
	if [ -z "$1" ]; then
	    admin_token=${default_passwd}
	fi
    else
	dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Admin token error\Zn" \
	    --msgbox "Sorry, admin-token don't match!\nPlease enter again" 8 45
	set_admin_token
    fi
}
# set mysql password
function set_mysql_passwd(){
    dialog --no-shadow --backtitle "$BACKTITLE" --title "Please input your mysql password" --cancel-label "Quit"\
	--inputbox "Enter your password" 8 40 $mysql_passwd 2>/tmp/mysql.pwd
    result=$?
    case $result in
	0) mysql_passwd=$(cat /tmp/mysql.pwd)
	    if [ -z $mysql_passwd ]; then
		dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Password error\Zn" \
		--msgbox "Input can not be empty" 10 30
		set_mysql_passwd
	    else
		set_mysql_passwd_again
    	    fi;;
	1) exit;;
	255) exit;;
    esac 
}

# set mysql password again
function set_mysql_passwd_again(){
    dialog --no-shadow --backtitle "$BACKTITLE" --title "Please input your mysql password again" --cancel-label "Back"\
	--inputbox "Enter your password again" 8 50 $mysql_passwd 2>/tmp/mysql.pwd
    result=$?
    pwd_again=$(cat /tmp/mysql.pwd)
    case $result in
	0) jude_mysql_passwd $pwd_again $mysql_passwd;;
	1) set_mysql_passwd;;
	255) exit;;
    esac
}

# jude two mysql passwords are same
# param: $1, pwd_again
# param:	$2, mysql_passwd
function jude_mysql_passwd(){
    if [ "$1" == "$2" ]; then
	if [ -z "$1" ]; then
	    mysql_passwd=${default_passwd}
	fi
    else
	dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Mysql password error\Zn" \
	    --msgbox "Sorry, Mysql password don't match!\nPlease enter again" 8 45
	set_mysql_passwd
    fi
}

# jude ip is valid
# return: $IP_INVALID(ip is invalid)
#	  $IP_VALID(ip is valid)	
function is_valid_ip() {
    r=`echo $1 | egrep '^[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}$'`
    if [ -z "$r" ]; then
	dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Ip error\Zn" \
	    --msgbox "Sorry, your ip is invalid!\nPlease enter again" 8 45
	return $IP_INVALID
    else
	return $IP_VALID
    fi	
}

# input primary network ip
function mysql_pri_nic(){
    dialog --no-shadow --backtitle "$BACKTITLE" --title "Please input the ip of primary network in mysql node" --cancel-label "Quit"\
        --inputbox "Enter the ip of primary network in mysql node" 8 60 2> /var/mysql_pri_nic.ip
    result=$?
    nic_ip=$(cat /var/mysql_pri_nic.ip)
    case $result in
	0) is_valid_ip ${nic_ip}
	    if [ "$?" == "$IP_VALID" ]; then 
		mysql_pri_ip=${nic_ip}
		echo $mysql_pri_ip > /var/mysql_pri_nic.ip
	    else
		mysql_pri_nic
	    fi;;
	1) exit;;
	255) exit;;
    esac
}
# input primary network ip
function mysql_sec_nic(){
    dialog --no-shadow --backtitle "$BACKTITLE" --title "Please input the ip of second network in mysql node" --cancel-label "Quit"\
        --inputbox "Enter the ip of second network in mysql node" 8 60 2> /var/mysql_sec_nic.ip
    result=$?
    nic_ip=$(cat /var/mysql_sec_nic.ip)
    case $result in
	0) is_valid_ip ${nic_ip}
	    if [ "$?" == "$IP_VALID" ]; then 
		mysql_sec_ip=${nic_ip}
		echo $mysql_sec_ip > /var/mysql_pri_nic.ip
	    else
		mysql_sec_nic
	    fi;;
	1) exit;;
	255) exit;;
    esac
    rm /var/mysql_pri_nic.ip
}

# input primary network ip
function control_pri_nic(){
    default_ext_net_cidr=${ext_nic_ip%\.*}
    dialog --no-shadow --backtitle "$BACKTITLE" --title "Please input the ip of primary network in control node" --cancel-label "Quit"\
        --inputbox "Enter the ip of primary network in control node" 8 60 $default_ext_net_cidr"." 2> /var/pri_nic.ip
    result=$?
    nic_ip=$(cat /var/pri_nic.ip)
    case $result in
	0) is_valid_ip ${nic_ip}
	    if [ "$?" == "$IP_VALID" ]; then 
		control_pri_ip=${nic_ip}
		echo $control_pri_ip > /var/pri_nic.ip
	    else
		control_pri_nic
	    fi
	    control_pri_forward_ip=${control_pri_ip%\.*}
	    if [ "$default_ext_net_cidr" != "$control_pri_forward_ip" ]; then
	        dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Error\Zn" \
	    	    --msgbox "Sorry, the ip of primary network in control node is wrong!\nPlease enter again" 8 45
	    	control_pri_nic
	    fi;;
	1) exit;;
	255) exit;;
    esac
}

# input second network ip
function control_sec_nic(){
    default_manage_forward_ip=${control_node_ip%\.*}
    dialog --no-shadow --backtitle "$BACKTITLE" --title "Please input the ip of second network in control node" --cancel-label "Quit"\
        --inputbox "Enter the ip of second network in control node" 8 60 $default_manage_forward_ip"." 2> /tmp/sec_nic.ip
    result=$?
    sec_ip=$(cat /tmp/sec_nic.ip)
    case $result in
	0) is_valid_ip ${sec_ip} 
	    if [ "$?"  == "$IP_VALID" ]; then 
		control_sec_ip=${sec_ip}
	    else
		control_sec_nic
	    fi
	    control_sec_forward_ip=${control_sec_ip%\.*}
	    if [ "$default_manage_forward_ip" != "$control_sec_forward_ip" ]; then
	        dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "\Zb\Z1Error\Zn" \
	    	    --msgbox "Sorry, the ip of second network in control node is wrong!\nPlease enter again" 8 45
	    	control_sec_nic
	    fi;;
	1) exit;;
	255) exit;;
    esac
}

# input control node root passwd
function input_control_node_root_password() {
    dialog --no-shadow --backtitle "$BACKTITLE" --title "Please input the root password of control node" --cancel-label "Quit"\
        --inputbox "Enter the root passwd of control node" 8 60 2> /var/control_node_root_password.ip
    result=$?
    case $result in
	0) jude_control_node_root_password ;;
	1) exit;;
	255) exit;;
    esac
}

# jude control node root password
function jude_control_node_root_password(){
    if [ -f /tmp/api-paste.ini ]; then
	rm /tmp/api-paste.ini
    fi
    export control_node_root_password=`cat /var/control_node_root_password.ip`
    scp_wrapper root@$control_pri_ip:/etc/nova/api-paste.ini /tmp/ $control_node_root_password >>${LOG_FILE} 2>>${ERR_FILE}
    scp_wrapper root@$control_pri_ip:/var/admin.pwd /tmp/ $control_node_root_password >>${LOG_FILE} 2>>${ERR_FILE}
    admin_token=`cat /tmp/admin.pwd`
#    scp_wrapper root@$control_pri_ip:/etc/authorized_keys /var/lib/nova/.ssh/ >>${LOG_FILE} 2>>${ERR_FILE}
#    copy_id_to_authorized_keys >>${LOG_FILE} 2>>${ERR_FILE}
#    scp_wrapper /var/lib/nova/.ssh/authorized_keys root@$control_pri_ip:/etc/authorized_keys >>${LOG_FILE} 2>>${ERR_FILE}
    if [ ! -f /tmp/api-paste.ini ]; then
        dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "Verify the root password of control_node\Zb\Z1Input wrong the first time\Zn" \
           --yes-label "Retry" --no-label "Input Again" \
           --yesno "\nTest control node password \
	  $control_node_root_password failed!\n
	  Please ensure that you have set the rootpasswd in your control_node and your input correctly" 8 100
	result=$?
	case $result in
	    0) jude_control_node_root_password_second ;;
	    1) input_control_node_root_password ;;
	    255) exit ;;
        esac
    fi
    rm /var/control_node_root_password.ip
    rm /tmp/api-paste.ini
}

function jude_control_node_root_password_second(){
    if [ -f /tmp/api-paste.ini ]; then
	rm /tmp/api-paste.ini
    fi
    scp_wrapper root@$control_pri_ip:/etc/nova/api-paste.ini /tmp/ $control_node_root_password >>${LOG_FILE} 2>>${ERR_FILE}
    if [ ! -f /tmp/api-paste.ini ]; then
        dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "Verify the root password of control_node\Zb\Z1Input wrong the second time\Zn" \
           --yes-label "Retry" --no-label "Input Again" \
           --yesno "\nTest control node password \
	  $control_node_root_password failed!\n
	  Please ensure that you have set the rootpasswd in your control_node and your input correctly" 8 100
	result=$?
	case $result in
	    0) jude_control_node_root_password_third ;;
	    1) input_control_node_root_password ;;
	    255) exit ;;
        esac
    fi
    rm /var/control_node_root_password.ip
    rm /tmp/api-paste.ini
}

function jude_control_node_root_password_third(){
    if [ -f /tmp/api-paste.ini ]; then
	rm /tmp/api-paste.ini
    fi
    scp_wrapper root@$control_pri_ip:/etc/nova/api-paste.ini /tmp/ $control_node_root_password >>${LOG_FILE} 2>>${ERR_FILE}
    if [ ! -f /tmp/api-paste.ini ]; then
        dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "Verify the root password of control_node\Zb\Z1Input wrong the third time\Zn" \
           --yes-label "Input Again" --no-label "Quit" \
           --yesno "\nTest control node password \
	  $control_node_root_password failed!\n
	  Please ensure that you have set the rootpasswd in your control_node and your input correctly" 8 100
	result=$?
	case $result in
	    0) input_control_node_root_password ;;
	    1) exit ;;
	    255) exit ;;
        esac
    fi
    rm /var/control_node_root_password.ip
    rm /tmp/api-paste.ini
}

function scp_wrapper {
    if [ -z "`which expect`" ]; then
	apt-get install -y --force-yes expect >/dev/null
    fi
    expect -c "
        set timeout 50;
        spawn scp -o StrictHostKeyChecking=no -oCheckHostIP=no $1 $2
        expect {
                    *assword:* {send -- $3\r;
                                 expect {
                                    *denied* {exit 2;}
                                    eof
                                 }
                    }
                    eof         {exit 1;}
                }
              "
}

# input control node mysql passwd
function input_control_node_mysql_password() {
    dialog --no-shadow --backtitle "$BACKTITLE" --title "Please input  mysql password of the control node " --cancel-label "Quit"\
        --inputbox "Enter mysql passwd of the control node " 8 60 2> /tmp/control_node_mysql_password.ip
    result=$?
    pwd=`cat /tmp/control_node_mysql_password.ip`
    case $result in
	0) jude_control_node_mysql_password $pwd;;
	1) exit;;
	255) exit;;
    esac
}

#jude control node mysql password
function jude_control_node_mysql_password(){
    result=`mysql -h$control_pri_ip -uroot -p$1 -e "show databases;" | awk '{print $1}' | grep Database`
    if [ "$result" != "Database" ]; then
        dialog --no-shadow --backtitle "$BACKTITLE" --title "Start ip address!" \
	    --msgbox "Sorry, your mysql password is wrong!\nPlease enter again!" 8 45
	input_control_node_mysql_password
    fi
}

# modify dnsmasq settings in order to ping hostname
function modify_dns_setting(){
    scp_wrapper root@$control_pri_ip:/etc/dnsmasq.hosts /tmp/ $control_node_root_password >>${LOG_FILE} 2>>${ERR_FILE}
    hostnm=`hostname -f`
    echo ${ext_nic_ip}" "${hostnm} >>/tmp/dnsmasq.hosts
    scp_wrapper /tmp/dnsmasq.hosts root@$control_pri_ip:/etc/dnsmasq.hosts $control_node_root_password >>${LOG_FILE} 2>>${ERR_FILE} 

    rm $HOME/.ssh/known_hosts
    ssh_wrapper root@$control_pri_ip service dnsmasq restart >>${LOG_FILE} 2>>${ERR_FILE}
    echo $control_pri_ip > /var/mysql_nic.ip
    echo $mysql_passwd > /tmp/mysql_passwd.log
}

function ssh_wrapper(){
    if [ -z "`which expect`" ]; then
	apt-get install -y --force-yes expect >/dev/null
    fi
    expect -c "spawn ssh -oStrictHostKeyChecking=no -oCheckHostIP=no $1 $2 $3 $4
    	set timeout 100
	expect 	\"password\"  
	send \"$control_node_root_password\r\n\" 
        expect eof"
}

function copy_id_to_authorized_keys(){
    usermod -s /bin/bash nova
    cd /var/lib/nova/.ssh/
    if [ -f id_rsa ]; then
	rm id_rsa
    fi
    if [ -f id_rsa.pub ]; then
	rm id_rsa.pub
    fi
    expect -c "spawn su - nova -c \"ssh-keygen \-t rsa\"
    expect \"Enter file in which to save the key\"
    send \"\n\"
    expect \"Enter passphrase\"
    send \"\n\"
    expect \"Enter same passphrase again\"
    send \"\n\"
    expect eof"
    host=`hostname`
    other_key=`cat authorized_keys | egrep -v $host`
    echo $other_key > ./authorized_keys
    echo `cat id_rsa.pub` >>./authorized_keys
    echo  >>./authorized_keys
}

function report_to_dialog(){
    echo $?@ | dialog --keep-window --no-shadow --backtitle "$BACKTITLE" --title "$1" --gauge "$2" 7 150 "$3"
}

# control node install progress
function all_in_one_percent(){
        report_to_dialog "$title" "All-in-one install..." 0
#    echo  >/etc/authorized_keys;chmod 644 /etc/authorized_keys >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Modify network..." 1
    modify_network >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    add_grizzly_repo
    sleep 1
    report_to_dialog "$title" "Update system..." 10
    update_system
    install_dependency
    install_keystone
    report_to_dialog "$title" "Source authentication service..." 21
    cp tools/keystone_data.sh /tmp/;chmod u+x /tmp/keystone_data.sh >> ${LOG_FILE} 2>>${ERR_FILE}
    . /tmp/keystone_data.sh >> ${LOG_FILE} 2>>${ERR_FILE}
    install_glance
    install_quantum
    report_to_dialog "$title" "Source virtual network service..." 50
    cp tools/quantum_data.sh /tmp/;chmod u+x /tmp/quantum_data.sh >> ${LOG_FILE} 2>>${ERR_FILE}
    . /tmp/quantum_data.sh >> ${LOG_FILE} 2>>${ERR_FILE}
    install_cinder
    install_nova
    report_to_dialog "$title" "Install monitor..." 85
    install_monitor >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install voyage..." 87
    install_voyage >> ${LOG_FILE} 2>>${ERR_FILE}
    install_horizon --purge
    report_to_dialog "$title" "Install management platform..." 90
    configure_network --install >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install creeper..." 92
    install_creeper
    report_to_dialog "$title" "Install task done" 100
}

function control_percent(){
    report_to_dialog "$title" "Control install..." 0
#    echo  >/etc/authorized_keys;chmod 644 /etc/authorized_keys >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Modify network..." 1
    modify_network >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    add_grizzly_repo
    sleep 1
    report_to_dialog "$title" "Update system..." 10
    update_system
    install_dependency
    install_keystone
    report_to_dialog "$title" "Source authentication service..." 22
    cp tools/keystone_data.sh /tmp/;chmod u+x /tmp/keystone_data.sh >> ${LOG_FILE} 2>>${ERR_FILE}
    . /tmp/keystone_data.sh >> ${LOG_FILE} 2>>${ERR_FILE}
    install_glance
    install_quantum
    report_to_dialog "$title" "Source virtual network service..." 50
    cp tools/quantum_data.sh /tmp/;chmod u+x /tmp/quantum_data.sh >> ${LOG_FILE} 2>>${ERR_FILE}
    . /tmp/quantum_data.sh >> ${LOG_FILE} 2>>${ERR_FILE}
    install_cinder
    install_nova
    report_to_dialog "$title" "Install monitor..." 85
    install_monitor >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install voyage..." 87
    install_voyage >> ${LOG_FILE} 2>>${ERR_FILE}
    install_horizon --purge
    report_to_dialog "$title" "Install management platform..." 90
    configure_network --install >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install creeper..." 92
    install_creeper
    report_to_dialog "$title" "Install task done" 100
}

# compute node install progress
function compute_percent(){
    title="Cascading Mode Compute Service Install"
    report_to_dialog "$title" "Compute install." 0
    sleep 1
    report_to_dialog "$title" "Compute install.." 1
    sleep 1
    report_to_dialog "$title" "Compute install..." 2
    sleep 1
    report_to_dialog "$title" "Modify network..." 3
    modify_network_dns >>${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    add_grizzly_repo
    install_bridge
    install_quantum
    install_compute_nova
    report_to_dialog "$title" "Install monitor..." 49
    install_monitor >> ${LOG_FILE} 2>>${ERR_FILE}
    install_kvm
    report_to_dialog "$title" "Enable spice server..." 77
    upgrade_kvm
    report_to_dialog "$title" "nova all restart." 90
    sleep 1
    nova_all_restart >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "add hosts compute in database." 94
    sleep 1
    report_to_dialog "$title" "add hosts compute in database.." 96
    sleep 1
    report_to_dialog "$title" "add hosts compute in database..." 98
    sleep 1
    add_hosts_compute_in_database >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install task done" 100
}
# multi storage install progress
function multi_storage_percent(){
    title="Storage Mode Multi Storage Install"
    add_grizzly_repo
    update_system
    install_dependency
    install_cinder
    report_to_dialog "$title" "Install monitor" 97
    install_monitor >>${LOG_FILE} 2>>${ERR_FILE};
    add_hosts_storage_in_database >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Install task done" 100
}
# single storage install progress
function single_storage_percent(){
    title="Storage Mode Single Storage Install"
    add_grizzly_repo
    update_system
    install_dependency
    install_storage
    report_to_dialog "$title" "Install monitor" 96
    install_monitor >>${LOG_FILE} 2>>${ERR_FILE};
    add_hosts_storage_in_database >>${LOG_FILE} 2>>${ERR_FILE};
    report_to_dialog "$title" "Install task done" 100
}
# self verfication progress
function self-verification_percent() {
    if [ -z "`which dialog`" ]; then
	if [ -e ./debs/dialog_1.1-20111020-1_amd64.deb ]; then
	    dpkg -i debs/dialog_1.1-20111020-1_amd64.deb >/dev/null 2>&1
	else
	    echo "can't find the file ./debs/dialog_1.1-20111020-1_amd64.deb"
	    exit 1
	fi
    fi
    if [ -f ${ERR_PERCENT_LOG} ]; then
	sudo rm -f ${ERR_PERCENT_LOG}
    fi
    {
	percent=0 
	while [ $percent -le 100 ]; do
            echo "XXX"
            echo $percent
            case $percent in
		0)  echo 'self-verification...'; percent=10;;
		10) assert_root
			if [ $? == $ASSERT_SUCCESS ]; then
			echo 'assert_root...'
                        percent=15
		    else
			echo 'this program must run by root'
			sleep 5
 			percent=101
		    fi  ;;
		15) detect_system_info
		    if [ $? == $SYSTEM_INFO_ERROR ]; then
			echo "your system info ubuntu $os_codename $bit $version should be precise x86_64 12.04.2..."
			sleep 5
     		        percent=101
		    else echo "assert_system_info_support"
                        percent=20
		    fi  ;;
                20) assert_kvm_ok
		    if [ $? == $ASSERT_SUCCESS ]; then
			echo 'assert_kvm_ok...' 
			percent=40
		    else
			echo ' virtualization technology is not supported by your CPU or BIOS'
			sleep 5
			percent=101
		    fi  ;;
		40) assert_resources_exist
		    if [ $? == $ASSERT_RES_EXIST_ERROR ]; then
			echo " ${file} is missing"
			sleep 5
     		        percent=101
		    else echo 'assert_resources_exist...' 
                        percent=50
		    fi  ;;
		50) detect_nic_numbers
		    if [ $? == $ASSERT_SUCCESS ]; then
			echo 'detect_nic_numbers...'
                        percent=70
		    else
			echo "there can't be less than two nics"
			sleep 5
 			percent=101
		    fi  ;;
		70) assert_primary_nic_ipv4_exists
		    if [ $? == $ASSERT_SUCCESS ]; then
			echo 'assert_primary_nic_ipv4_exists...'
                        percent=90
		    else
			echo "primary network interface or primary ipv4 does not exist"
			sleep 5
 			percent=101
		    fi  ;;
		90) assert_secondary_nic_ipv4_exists
		    if [ $? == $ASSERT_SUCCESS ]; then
			echo 'assert_secondary_nic_ipv4_exists...'
                        percent=100
		    else
			echo "secondary network interface or secondary ipv4 does not exist"
			sleep 5
 			percent=101
		    fi  ;;
		100)echo 'self-verification done'; percent=101;;
            esac
            echo "XXX"
	done
    }| dialog --no-shadow --backtitle "$BACKTITLE" --title "self-verification" \
        --gauge 100 7 150
}
