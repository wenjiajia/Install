#! /bin/bash

LIBVIRT_TYPE="qemu"
is_control=`which nova-scheduler`


# make log dir
# log will be generate if something very important happens
function make_log_dir() {
    if [ ! -d "/var/log/vrv" ]; then
        mkdir /var/log/vrv
    fi
    if [ ! -d "/var/log/vrv/cloud" ]; then
        mkdir /var/log/vrv/cloud
    fi
}

function force_install()
{
    apt-get install -y --force-yes $@
}

function add_grizzly_repo()
{
    report_to_dialog "$title" "Install ubuntu-cloud-keyring..." 5
    sleep 1
    report_to_dialog "$title" "Install ubuntu-cloud-keyring..." 6
    force_install ubuntu-cloud-keyring >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install python-software-properties..." 7
    sleep 1
    report_to_dialog "$title" "Install python-software-properties..." 8
    sleep 1
    report_to_dialog "$title" "Install python-software-properties..." 9
    sleep 1
    force_install python-software-properties >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install python-keyring..." 10
    sleep 1
    force_install python-keyring >>${LOG_FILE} 2>>${ERR_FILE}
    ntpdate $control_pri_ip  >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install python-memcache..." 10
    force_install python-memcache >> ${LOG_FILE} 2>>${ERR_FILE}
}

function install_ntp_service(){
    report_to_dialog "$title" "Install ntp..." 11
    sleep 1
    force_install ntp >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Ntp_config..." 12
    ntp_config >>${LOG_FILE} 2>>${ERR_FILE}
    sleep 2
    report_to_dialog "$title" "Service ntp stop..." 13
    sleep 1
    service ntp stop >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Service ntp start..." 14
    sleep 1
    service ntp start >>${LOG_FILE} 2>>${ERR_FILE}
}

function ntp_config(){
    if [ -z "$is_control" ]; then
        sed -i "s/server ntp.ubuntu.com/server $control_sec_ip/g" /etc/ntp.conf 
        #Comment the ubuntu NTP servers
        sed -i 's/server 0.ubuntu.pool.ntp.org/#server 0.ubuntu.pool.ntp.org/g' /etc/ntp.conf
        sed -i 's/server 1.ubuntu.pool.ntp.org/#server 1.ubuntu.pool.ntp.org/g' /etc/ntp.conf
        sed -i 's/server 2.ubuntu.pool.ntp.org/#server 2.ubuntu.pool.ntp.org/g' /etc/ntp.conf
        sed -i 's/server 3.ubuntu.pool.ntp.org/#server 3.ubuntu.pool.ntp.org/g' /etc/ntp.conf   
    fi
}

function install_bridge()
{
    report_to_dialog "$title" "Install vlan..." 15
    sleep 1
    force_install vlan >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install bridge-utils...." 16
    sleep 1
    force_install bridge-utils >>${LOG_FILE} 2>>${ERR_FILE}
    sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/" /etc/sysctl.conf >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Sysctl..." 17
    sleep 1
    sysctl net.ipv4.ip_forward=1 >>${LOG_FILE} 2>>${ERR_FILE}
    cp -r ./res/license /usr/lib/python2.7/dist-packages/ >> ${LOG_FILE} 2>>${ERR_FILE}
}

function safe_sed_ovs_quantum_plugin()
{
    if ! grep "^[ ]*$1[ ]*=" /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini ; then
        sed -i "/^\[OVS\]/a $1 = $2" /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
    else
        sed -i "s/^[ ]*$1[ ]*=.*/$1 = $2" /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
    fi
}

function nova_all_restart()
{
    pushd /etc/init.d
    for i in $( ls nova-* ); do service $i restart; done
    popd
}

function install_quantum(){
    purge_quantum
    if [ -z "$is_control" ]; then
       install_compute_quantum
    fi
}

function purge_quantum()
{
    report_to_dialog "$title" "Remove openvswitch-switch..." 18
    sleep 1
    apt-get autoremove --purge -y openvswitch-switch >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove openvswitch-datapath-dkms..." 19
    sleep 1
    apt-get autoremove --purge -y openvswitch-datapath-dkms >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove virtual network service-server..." 20
    sleep 1
    apt-get autoremove --purge -y quantum-server >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove virtual network service-plugin-openvswitch..." 21
    sleep 1
    apt-get autoremove --purge -y quantum-plugin-openvswitch >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove virtual network service-plugin-openvswitch-agent..." 22
    sleep 1
    apt-get autoremove --purge -y quantum-plugin-openvswitch-agent >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove dnsmasq..." 23
    sleep 1
    apt-get autoremove --purge -y dnsmasq >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove virtual network service-dhcp-agent..." 24
    sleep 1
    apt-get autoremove --purge -y quantum-dhcp-agent >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove virtual network service-l3-agent..." 25
    sleep 1
    apt-get autoremove --purge -y quantum-l3-agent >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove virtual network service configuration..." 26
    sleep 1
    rm -rf /var/lib/quantum >>${LOG_FILE} 2>>${ERR_FILE}
    rm -rf /etc/quantum >>${LOG_FILE} 2>>${ERR_FILE}
}

function install_compute_quantum()
{
    report_to_dialog "$title" "Install openvswitch datapath-source..." 27
    ### install openvswitch
    force_install openvswitch-datapath-source >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install openvswitch datapath..." 28
    module-assistant auto-install openvswitch-datapath >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install openvswitch switch..." 29
    force_install openvswitch-switch >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install openvswitch brcompat..." 30
    force_install openvswitch-brcompat >> ${LOG_FILE} 2>>${ERR_FILE}
    sed -i 's/# BRCOMPAT=no/BRCOMPAT=yes/g' /etc/default/openvswitch-switch
    report_to_dialog "$title" "Service openvswitch-switch restart..." 31
    service openvswitch-switch restart >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 10
    report_to_dialog "$title" "Service openvswitch-switch restart twice..." 32
    service openvswitch-switch restart >> ${LOG_FILE} 2>>${ERR_FILE}
    lsmod | grep brcompat >> ${LOG_FILE} 2>>${ERR_FILE}
    ovs-vsctl add-br br-int >> ${LOG_FILE} 2>>${ERR_FILE}
    ### install quantum-plugin-openvswitch-agent
    report_to_dialog "$title" "Install openvswitch-plugin-openvswitch-agent..." 33
    force_install quantum-plugin-openvswitch-agent >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Change virtual network service configuration..." 34
    sleep 1
    quantum_config >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Service quantum-plugin-openvswitch-agent restart..." 35
    sleep 1
    service quantum-plugin-openvswitch-agent restart >> ${LOG_FILE} 2>>${ERR_FILE}
}

function quantum_config(){
    control_sec_ip=${control_sec_ip:-127.0.0.1}
sed -i "s/^sql_connection[ ]*=.*/sql_connection = mysql:\/\/quantum:$mysql_passwd@$control_sec_ip\/quantum/g" /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
    safe_sed_ovs_quantum_plugin "tenant_network_type" "gre"
    safe_sed_ovs_quantum_plugin "tunnel_id_ranges" "1:1000"
    safe_sed_ovs_quantum_plugin "integration_bridge" "br-int"
    safe_sed_ovs_quantum_plugin "tunnel_bridge" "br-tun"
    safe_sed_ovs_quantum_plugin "local_ip" "$control_node_ip"
    safe_sed_ovs_quantum_plugin "enable_tunneling" "True"
    
     sed -i -e "
s/[# ]*rabbit_host[ ]*=.*/rabbit_host = $control_sec_ip/g;
s/^auth_host[ ]*=.*/auth_host = $control_sec_ip/g;
s/^admin_tenant_name =.*/admin_tenant_name = service/g;
s/^admin_user =.*/admin_user = quantum/g;
s/^admin_password =.*/admin_password = $admin_token/g;
" /etc/quantum/quantum.conf
    sed -i "/bind_host/a  \memcached_servers = $control_sec_ip:11211" /etc/quantum/quantum.conf
    sed -i "/^\[QUOTAS\]/a quota_router = -1" /etc/quantum/quantum.conf
}

function purge_nova()
{
    report_to_dialog "$title" "Remove cpu-checker..." 36
    sleep 1
    apt-get autoremove --purge --yes cpu-checker >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove kvm..." 37
    sleep 1
    apt-get autoremove --purge --yes kvm >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove libvirt-bin..." 38
    sleep 1
    apt-get autoremove --purge --yes libvirt-bin >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove pm-utils..." 38
    sleep 1
    apt-get autoremove --purge --yes pm-utils >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove nova-api..." 39
    sleep 1
    apt-get autoremove --purge --yes nova-api >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove nova-cert..." 40
    sleep 1
    apt-get autoremove --purge --yes nova-cert >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove novnc..." 40
    sleep 1
    apt-get autoremove --purge --yes novnc >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove nova-consoleauth..." 40
    sleep 1
    apt-get autoremove --purge --yes nova-consoleauth >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove nova-scheduler..." 41
    sleep 1
    apt-get autoremove --purge --yes nova-scheduler >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove nova-novncproxy..." 41
    sleep 1
    apt-get autoremove --purge --yes nova-novncproxy >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove nova-doc..." 41
    sleep 1
    apt-get autoremove --purge --yes nova-doc >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove nova-conductor..." 42
    sleep 1
    apt-get autoremove --purge --yes nova-conductor >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove nova-compute-kvm..." 42
    sleep 1
    apt-get autoremove --purge --yes nova-compute-kvm >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove configuration..." 42
    sleep 1
    rm -rf /var/lib/libvirt >>${LOG_FILE} 2>>${ERR_FILE}
    rm -rf /etc/libvirt >>${LOG_FILE} 2>>${ERR_FILE}
    rm -rf /var/lib/nova >>${LOG_FILE} 2>>${ERR_FILE}
    rm -rf /etc/nova >>${LOG_FILE} 2>>${ERR_FILE}
}

function libvirt_config(){
    sed -i "s/^#\(cgroup_device_acl\)/\1/" /etc/libvirt/qemu.conf
    sed -i "s/^#\([ ]*\"\/dev\/null\"\)/\1/" /etc/libvirt/qemu.conf
    sed -i "s/^#\([ ]*\"\/dev\/random\"\)/\1/" /etc/libvirt/qemu.conf
    sed -i "s/^#\([ ]*\"\/dev\/ptmx\"\)/\1/" /etc/libvirt/qemu.conf
    sed -i "s/^#\([ ]*\"\/dev\/rtc\".*\)/\1, \"\/dev\/net\/tun\"/" /etc/libvirt/qemu.conf
    sed -i "s/^#\]$/\]/" /etc/libvirt/qemu.conf
    virsh net-destroy default
    virsh net-undefine default

    sed -i "s/[# ]*listen_tls[ ]*=.*/listen_tls = 0/" /etc/libvirt/libvirtd.conf
    sed -i "s/[# ]*listen_tcp[ ]*=.*/listen_tcp = 1/" /etc/libvirt/libvirtd.conf
    sed -i "s/[# ]*auth_tcp[ ]*=.*/auth_tcp =\"none\"/" /etc/libvirt/libvirtd.conf
    host_uuid=`python ./tools/host_uuid.py`
    sed -i -e "s/^#host_uuid =.*/host_uuid = \"$host_uuid\"/g;" /etc/libvirt/libvirtd.conf
    sed -i "s/[# ]*env libvirtd_opts[ ]*=.*/env libvirtd_opts=\"-d -l\"/g" /etc/init/libvirt-bin.conf
    sed -i "s/[# ]*libvirtd_opts[ ]*=.*/libvirtd_opts=\"-d -l\"/g" /etc/default/libvirt-bin
}

function install_compute_nova(){
    purge_nova
    ### install libvirt
    report_to_dialog "$title" "Install cpu-checker..." 43
    force_install cpu-checker >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Kvm-ok..." 43
    kvm-ok >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install kvm..." 44
    force_install kvm >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libvirt-bin..." 44
    force_install libvirt-bin >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install pm-utils..." 45
    force_install pm-utils >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Libvirt_config..." 45
    libvirt_config >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Service libvirt-bin restart..." 46
    service libvirt-bin restart >>${LOG_FILE} 2>>${ERR_FILE}
    # install nova-compute    
    report_to_dialog "$title" "Install nova-compute-kvm..." 47
    force_install nova-compute-kvm >>${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Nova_config..." 48
    nova_config >>${LOG_FILE} 2>>${ERR_FILE}
    #nova-manage db sync
    report_to_dialog "$title" "Nova_all_restart..." 48
    sleep 1
    nova_all_restart >>${LOG_FILE} 2>>${ERR_FILE}
}

function nova_config(){
    control_sec_ip=${control_sec_ip:-127.0.0.1}
    sed -i -e "
s/[# ]*auth_host =.*/auth_host = $control_sec_ip/;
s/^admin_tenant_name =.*/admin_tenant_name = service/g;
s/^admin_user =.*/admin_user = nova/g;
s/^admin_password =.*/admin_password = $admin_token/g;
s/^signing_dirname =.*/signing_dirname = \/tmp\/keystone-signing-nova/g;
s/^auth_version = .*/auth_version = v2.0/g;
" /etc/nova/api-paste.ini
    cat <<EOF >/etc/nova/nova.conf
[DEFAULT]
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/run/lock/nova
verbose=True
api_paste_config=/etc/nova/api-paste.ini
compute_scheduler_driver=nova.scheduler.simple.SimpleScheduler
rabbit_host=$control_sec_ip
nova_url=http://$control_sec_ip:8774/v1.1/
sql_connection=mysql://nova:$mysql_passwd@$control_sec_ip/nova
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
memcached_servers=$control_sec_ip:11211

# Auth
use_deprecated_auth=false
auth_strategy=keystone

# Imaging service
glance_api_servers=$control_sec_ip:9292
image_service=nova.image.glance.GlanceImageService

# Vnc configuration
vnc_enabled=false
novncproxy_base_url=http://$control_pri_ip:6080/vnc_auto.html
novncproxy_port=6080
vncserver_proxyclient_address=$control_node_ip
vncserver_listen=0.0.0.0

# Network settings
network_api_class=nova.network.quantumv2.api.API
quantum_url=http://$control_sec_ip:9696
quantum_auth_strategy=keystone
quantum_admin_tenant_name=service
quantum_admin_username=quantum
quantum_admin_password=$admin_token
quantum_admin_auth_url=http://$control_sec_ip:35357/v2.0
libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
linuxnet_interface_driver=nova.network.linux_net.LinuxOVSInterfaceDriver
firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver

#Metadata
service_quantum_metadata_proxy = True
quantum_metadata_proxy_shared_secret = helloOpenStack
metadata_host = $control_sec_ip
metadata_listen = 127.0.0.1
metadata_listen_port = 8775

# Compute #
compute_driver=libvirt.LibvirtDriver

# Cinder #
volume_api_class=nova.volume.cinder.API
osapi_volume_listen_port=5900

# Spice configuration
resume_guests_state_on_host_boot=true
[spice]
enabled=true
agent_enabled=false
html5proxy_base_url=http://$control_pri_ip:6082/spice_auto.html
server_listen=0.0.0.0
server_proxyclient_address=$ext_nic_ip

host_ip=$ext_nic_ip
my_ip=$control_node_ip
EOF
    cat <<EOF >/etc/nova/nova-compute.conf
[DEFAULT]
libvirt_type=$LIBVIRT_TYPE
libvirt_ovs_bridge=br-int
libvirt_vif_type=ethernet
libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
libvirt_use_virtio_for_bridges=True
EOF
}

function install_kvm(){
    report_to_dialog "$title" "Install gcc..." 50
    force_install gcc >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install g++..." 51
    force_install g++ >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install make..." 52
    force_install make >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libtool..." 53
    force_install libtool >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install liblog4cpp5-dev..." 54
    force_install liblog4cpp5-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libavcodec-dev..." 55
    force_install libavcodec-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libssl-dev..." 56
    force_install libssl-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install xlibmesa-glu-dev..." 57
    force_install xlibmesa-glu-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libasound-dev..." 58
    force_install libasound-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libpng12-dev..." 59
    force_install libpng12-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libfreetype6-dev..." 60
    force_install libfreetype6-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libsasl2-dev..." 61
    force_install libsasl2-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libfontconfig1-dev..." 62
    force_install libfontconfig1-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libogg-dev..." 63
    force_install libogg-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libxrandr-dev..." 64
    force_install libxrandr-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install kvm..." 65
    force_install kvm >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libgcrypt-dev..." 66
    force_install libgcrypt-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libsdl-dev..." 67
    force_install libsdl-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libnss3-dev..." 68
    force_install libnss3-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libpixman-1-dev..." 69
    force_install libpixman-1-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libxfixes-dev..." 70
    force_install libxfixes-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libjpeg8-dev..." 71
    force_install libjpeg8-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libsasl2-dev..." 72
    force_install libsasl2-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install python-pyparsing..." 73
    force_install python-pyparsing >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install glib-2.0-dev..." 74
    force_install glib-2.0-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libalsa-ocaml-dev..." 75
    force_install libalsa-ocaml-dev >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libusb-1.0-0.dev..." 76
    force_install libusb-1.0-0.dev >> ${LOG_FILE} 2>>${ERR_FILE}
}


function tar_source(){
    tar -xf ./kvm-sources.tar.gz -C res/
    for archive in $target/*
    do
        if [ -f $archive ]; then
            if [ ${archive##*.} == 'gz' ]; then
                tar -xzf $archive -C $target
            else
                tar -xjf $archive -C $target
            fi
        fi
    done    
}

function cp_link(){
    if [ -e $LOCAL_PATH/libusbredirparser.so.0.0.0 ]; then
        cp $LOCAL_PATH/libusbredirparser.so.0.0.0 $LIB_PATH
        rm $LIB_PATH/libusbredirparser.so.0
        ln -s $LIB_PATH/libusbredirparser.so.0.0.0 $LIB_PATH/libusbredirparser.so.0
    fi

    if [ -e $LOCAL_PATH/libspice-server.so.1.6.0 ]; then
        cp $LOCAL_PATH/libspice-server.so.1.6.0 $LIB_PATH
        if [ -e $LIB_PATH/libspice-server.so.1 ]; then
            rm $LIB_PATH/libspice-server.so.1
        fi
        ln -s $LIB_PATH/libspice-server.so.1.6.0 $LIB_PATH/libspice-server.so.1
        if [ -e $LIB_PATH/libspice-server.so ]; then
            rm $LIB_PATH/libspice-server.so
        fi
        ln -s $LIB_PATH/libspice-server.so.1.6.0 $LIB_PATH/libspice-server.so
    fi
}

function upgrade_kvm() 
{
    target=./res/kvm-sources/
    LIBVIRT_BIN=/etc/init.d/libvirt-bin
    LIB_PATH=/usr/lib/
    LOCAL_PATH=/usr/local/lib/
    report_to_dialog "$title" "Kvm sources..." 78
    tar_source >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libcacard." 79
    pushd $target/libcacard-0.1.2 >> ${LOG_FILE} 2>>${ERR_FILE}
    ./configure --quiet >> ${LOG_FILE} 2>>${ERR_FILE} && make -s >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libcacard.." 79
    make -s install >> ${LOG_FILE} 2>>${ERR_FILE}
    popd >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install spice-protocol." 80
    pushd $target/spice-protocol-0.12.2 >> ${LOG_FILE} 2>>${ERR_FILE}
    ./configure --quiet >> ${LOG_FILE} 2>>${ERR_FILE} && make -s >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install spice-protocol.." 80
    make -s install >> ${LOG_FILE} 2>>${ERR_FILE}
    popd >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install celt." 81
    pushd $target/celt-0.5.1.3 >> ${LOG_FILE} 2>>${ERR_FILE}
    ./configure --quiet >> ${LOG_FILE} 2>>${ERR_FILE} && make -s >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install celt.." 81
    make -s install >> ${LOG_FILE} 2>>${ERR_FILE}
    popd  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install usbredir." 82
    pushd $target/usbredir-0.4.4 >> ${LOG_FILE} 2>>${ERR_FILE}
    ./configure --quiet >> ${LOG_FILE} 2>>${ERR_FILE} && make -s >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install usbredir.." 82
    make -s install >> ${LOG_FILE} 2>>${ERR_FILE}
    popd >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install spice-0.12.2." 83
    pushd $target/spice-0.12.2 >> ${LOG_FILE} 2>>${ERR_FILE}
    ./configure --quiet --enable-smartcard --enable-client >> ${LOG_FILE} 2>>${ERR_FILE} && make -s >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install spice-0.12.2.." 83
    make -s install >> ${LOG_FILE} 2>>${ERR_FILE}
    popd >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install enable spice." 84
    sleep 1
    pushd $target/qemu-kvm-1.2.0 >> ${LOG_FILE} 2>>${ERR_FILE}
    ./configure --prefix=/usr --enable-spice --enable-kvm --audio-drv-list=alsa,oss --enable-system --enable-smartcard-nss \
    --enable-smartcard --enable-usb-redir --enable-attr --enable-bsd-user --enable-system --enable-tcg-interpreter \
    --enable-curses --enable-debug  --enable-debug-tcg --enable-user --enable-guest-agent --enable-guest-base \
    --enable-vhost-net --enable-vnc --enable-linux-user --enable-mixemu --enable-nptl --enable-pie --enable-sdl >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Make enable spice..." 85
    make -s >> ${LOG_FILE} 2>>${ERR_FILE} && make -s install >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Make enable spice...." 86
    popd >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Copy links..." 87
    cp_link >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Service libvirt-bin restart..." 88
    service libvirt-bin restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Copy configurations..." 89
    cp -r ./res/nova/* /usr/share/pyshared/nova/ >> ${LOG_FILE} 2>>${ERR_FILE}
    cp -r ./res/nova/etc/* /etc/ >> ${LOG_FILE} 2>>${ERR_FILE}
    rm -r /usr/share/pyshared/nova/etc/ >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Copy virtio-win-0.1-15.iso and virtio-WinXP-x86.vfd......" 90
    cp ./win/virtio-win-0.1-15.iso /var/lib/nova >> ${LOG_FILE} 2>>${ERR_FILE}
    cp ./win/virtio-WinXP-x86.vfd /var/lib/nova >> ${LOG_FILE} 2>>${ERR_FILE}
    version=`qemu-system-x86_64 --version | awk '{print $4}'`
    if [ $version != "1.2.0" ]; then
        echo "Sorry,your qemu-system-x86_64 --version must be 1.2.0 "
        sleep 10
        exit
    fi
}

# add dns-nameservers config to /etc/network/interfaces
function modify_network_dns() {
    primary_nic=`get_primary_interface_label`
    primary_nic_ipv4=`get_interface_ipv4 $primary_nic`
    gateway=`get_gateway`
    netmask=`get_netmask $primary_nic`
    network=${primary_nic_ipv4%\.*}".0"
    backup_file "/etc/network/interfaces"
    
cat <<INTERFACESWITHDNS > /etc/network/interfaces
auto lo
iface lo inet loopback

auto $primary_nic
iface $primary_nic inet static
address $primary_nic_ipv4
netmask $netmask
gateway $gateway
network $network
dns-nameservers $control_pri_ip

auto $second
iface $second inet static
address $control_node_ip
netmask $netmask

INTERFACESWITHDNS
    sed -i -e "s/^127.0.1.1.*/${ext_nic_ip}   ${hostnm}/g;" /etc/hosts
    /etc/init.d/networking restart
}

# Author: Qinglong Meng
# Date: 2013-6-21
# Desc: monitor install
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

function add_hosts_compute_in_database(){
    python ./tools/add_hosts.py compute_node
}
