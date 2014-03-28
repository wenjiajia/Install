#! /bin/bash

function install_start(){
    select variable in "Continue" "Quit"
    do
	if [ $variable ];then
            if [ $variable == "Quit" ];then
		echo "Quit Now"
		echo "..."
		sleep 1
		echo ".."
		sleep 1
		echo "."
		sleep 1
		exit 1
            elif [ $variable == "Continue" ];then
                echo "Install now"
	        sleep 1
            fi
            break
        else
            echo "Invaild selection"
        fi
    done
}

if [ `whoami` != "root" ]; then
    echo "this program must run by root"
    echo "Quit now"
    echo "..."
    sleep 1
    echo ".."
    sleep 1
    echo "."
    sleep 1
    exit
fi

time=`date`
echo "Install start $time" >> ./.system.log

echo "Input 1 or 2 and Press [Enter] to select"
select variable in "Install" "Quit"
do
    if [ $variable ];then
        if [ $variable == "Quit" ];then
	    echo "Quit Now"
            echo "..."
            sleep 1
            echo ".."
            sleep 1
            echo "."
            sleep 1
            exit 1
        elif [ $variable == "Install" ];then
	    echo "IMPORTANT!! Your installation will change your system!"
            install_start
        fi
        break
    else
	echo "Invaild selection"
    fi
done

if [ -e ./tools/api.sh ]; then
    source ./tools/api.sh
else
    echo "can't find the file ./tools/api.sh"
    sleep 5
    exit 1
fi

if [ -e ./tools/ERROR_AND_OK_NUM ]; then
    source ./tools/ERROR_AND_OK_NUM
else
    echo "can't find the file ./tools/ERROR_AND_OK_NUM"
    sleep 5
    exit 1
fi

# install all_in_one node
function install_all_in_one() {  
    if [ -f ./tools/install_node ]; then
        source ./tools/install_node --all_in_one
	exit 0
    else
        echo "can't find the file ./tools/install_node"
	sleep 5
        exit 1
    fi
}
#install all_in_one_single_storage
function install_all_in_one_single_storage(){
    if [ -f ./tools/install_node ]; then
        source ./tools/install_node --all_in_one_single_storage
	exit 0
    else
        echo "can't find the file ./tools/install_node"
	sleep 5
        exit 1
    fi
}
#install all_in_one_multi_storage
function install_all_in_one_multi_storage(){
    if [ -f ./tools/install_node ]; then
        source ./tools/install_node --all_in_one_multi_storage
	exit 0
    else
        echo "can't find the file ./tools/install_node"
	sleep 5
        exit 1
    fi
}
# install control node
function install_control_node() {
    if [ -f ./tools/install_node ]; then
        source ./tools/install_node --control_node
	exit 0
    else
        echo "can't find the file ./tools/install_node"
        exit 1
    fi
}
# install control node single storage
function install_control_node_single_storage(){
    if [ -f ./tools/install_node ]; then
        source ./tools/install_node --control_node_single_storage
	exit 0
    else
        echo "can't find the file ./tools/install_node"
        exit 1
    fi
}
# install control node multi storage
function install_control_node_multi_storage(){
    if [ -f ./tools/install_node ]; then
        source ./tools/install_node --control_node_multi_storage
	exit 0
    else
        echo "can't find the file ./tools/install_node"
        exit 1
    fi
}
# install compute node
function install_compute_node() {  
    if [ -f ./tools/install_node ]; then
        source ./tools/install_node --compute_node
	exit 0
    else
        echo "can't find the file ./tools/install_node"
	sleep 5
        exit 1
    fi
}
# install single storage node
function install_single_storage(){
    if [ -f ./tools/install_node ]; then
        source ./tools/install_node --single_storage
	exit 0
    else
        echo "can't find the file ./tools/install_node"
	sleep 5
        exit 1
    fi
}
# install multi storage node
function install_multi_storage(){
    if [ -f ./tools/install_node ]; then
        source ./tools/install_node --multi_storage
	exit 0
    else
        echo "can't find the file ./tools/install_node"
	sleep 5
        exit 1
    fi
}

# main gui menu
# self verfication and
# select which node to install
function report_result() {
    if [ -f ${ERR_PERCENT_LOG} ]; then
        assert_result=`less ${ERR_PERCENT_LOG}`
    fi

    if [ "$assert_result" == "$ASSERT_ROOT_ERROR" ];then
	dialog --backtitle "$BACKTITLE" --exit-label "Quit" --textbox ./stat/1.sh 15 45
 	exit
    elif [ "$assert_result" == "$SYSTEM_INFO_ERROR" ];then
	dialog --backtitle "$BACKTITLE" --exit-label "Quit" --textbox ./stat/1.5.sh 15 45
	exit
    elif [ "$assert_result" == "$ASSERT_KVM_ERROR" ];then
	dialog --backtitle "$BACKTITLE" --exit-label "Quit" --textbox ./stat/2.sh 15 45
	exit
    elif [ "$assert_result" == "$ASSERT_RES_EXIST_ERROR" ];then
	dialog --backtitle "$BACKTITLE" --exit-label "Quit" --textbox ./stat/3.sh 15 45
	exit	
    elif [ "$assert_result" == "$ASSERT_NIC_NUMBERS_ERROR"  ];then
	dialog --backtitle "$BACKTITLE" --exit-label "Quit" --textbox ./stat/4.sh 15 45
	exit
    elif [ "$assert_result" == "$ASSERT_PRINIC_EXIST" ];then
	dialog --backtitle "$BACKTITLE" --exit-label "Quit" --textbox ./stat/5.sh 15 45
	exit	
    elif [ "$assert_result" == "$ASSERT_SECNIC_EXIST" ];then
	dialog --backtitle "$BACKTITLE" --exit-label "Quit" --textbox ./stat/6.sh 15 45
	exit
    else 
	dialog --backtitle "$BACKTITLE" --exit-label "OK" --textbox ./stat/7.sh 15 45
	case $? in
	    1) exit;;
	    255) exit;;
    	esac
    fi
    mode_menu
}

function cascading_mode_menu(){
    dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "Cascading Mode Menu" --ok-label "Continue" --cancel-label "Quit"\
        --menu "\Zb\Z1Cascading Mode Select\Zn" 15 50 8\
        "Control Node" ""\
        "Compute  Node" ""\
        "Control&compute(without storage) Node" ""\
        "Control&compute(mount storage) Node" ""\
        "Control(without storage) Node" ""\
        "Control(mount storage) Node" ""\
        "Back to Main Menu" "" 2> /tmp/dialog.out
    if [ ${?} != 0 ]; then rm /tmp/dialog.out; exit; fi
    case `cat /tmp/dialog.out` in
        "Control Node") assert_partition_exist; install_control_node;;
        "Compute  Node") install_compute_node;;
        "Control&compute(without storage) Node") install_all_in_one_multi_storage;;
        "Control&compute(mount storage) Node") install_all_in_one_single_storage;;
        "Control(without storage) Node") install_control_node_multi_storage;;
        "Control(mount storage) Node") install_control_node_single_storage;;
        "Back to Main Menu") rm /tmp/dialog.out; mode_menu;;
    esac
}

function storage_mode_menu(){
    dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "Storage Mode Menu" --ok-label "Continue" --cancel-label "Quit"\
        --menu "\Zb\Z1Storage Mode Select\Zn" 10 50 3\
        "Multi-storage  Node" ""\
        "Single-storage Node" ""\
        "Back to Main Menu" "" 2> /tmp/dialog.out
    if [ ${?} != 0 ]; then rm /tmp/dialog.out; exit; fi
    case `cat /tmp/dialog.out` in
        "Multi-storage  Node") assert_partition_exist; install_multi_storage;;
        "Single-storage Node") assert_partition_exist; install_single_storage;;
        "Back to Main Menu") rm /tmp/dialog.out; mode_menu;;
    esac
}

function mode_menu(){
    dialog --colors --no-shadow --backtitle "$BACKTITLE" --title "Main Menu" --ok-label "Continue" --cancel-label "Quit"\
        --menu "\Zb\Z1Mode Select\Zn" 10 55 3\
        "Single    Mode" "install all available services"\
        "Cascading Mode" "install cascading services"\
        "Storage   Mode" "install storage services" 2> /tmp/dialog.out
    if [ ${?} != 0 ]; then rm /tmp/dialog.out; exit; fi
    case `cat /tmp/dialog.out` in
        "Single    Mode") assert_partition_exist; install_all_in_one;;
        "Cascading Mode") cascading_mode_menu;;
        "Storage   Mode") storage_mode_menu;;
    esac
    rm /tmp/dialog.out
}

function label_cinder_volumes(){
    if [ -e /var/log/partition.sh ]; then
	service iscsitarget stop
        part=`cat /var/log/partition.sh`
	vgremove -f vrv-volumes
        vgremove -f vrv-cloud
	pvremove ${part}
	mkfs.ext4 ${part}
	tune2fs -L vrv-volumes ${part}
    fi  
}

function recovery_network(){
    if [ -n "`which brctl`" ]; then
	brctl show | awk '{print $1}' > /tmp/br
    fi
    if [ -e /tmp/br ]; then
	for br in `cat /tmp/br`; do
	    brctl delbr $br
	done
    fi	
    if [ -f /etc/network/interfaces.vrv.bak ]; then
	mv /etc/network/interfaces.vrv.bak /etc/network/interfaces
    fi  
    /etc/init.d/networking restart
}

label_cinder_volumes >>${LOG_FILE} 2>>${ERR_FILE}
recovery_network >>${LOG_FILE} 2>>${ERR_FILE}
if [ -e debs.tgz ]; then
    tar xvf debs.tgz >>${LOG_FILE} 2>>${ERR_FILE}
else
    echo "can't find the file debs.tgz"
    sleep 5
    exit 1
fi
self-verification_percent
add_grizzly_source >>${LOG_FILE} 2>>${ERR_FILE}
report_result
mode_menu
revert_sources_list
