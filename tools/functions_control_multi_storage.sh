#! /bin/bash

export BAK_POSTFIX=".vrv.bak"
hostnm=`hostname -f`
metadata=vrv.smart.cloud.manager.`date '+%Y%m%d%H%M%S.%N'`

function configure_network()
{
    ovs-vsctl add-port br-ex eth0
##For Exposing OpenStack API over the internet
    if [ -f /etc/network/interfaces.withbrex ];then
        mv /etc/network/interfaces.withbrex /etc/network/interfaces   
    fi
    sed -i -e "s/^127.0.1.1.*/${ext_nic_ip}  ${hostnm}/g;" /etc/hosts
    /etc/init.d/networking restart
    service quantum-server restart
    service quantum-l3-agent restart
    service quantum-dhcp-agent restart
    service quantum-metadata-agent restart
    service quantum-plugin-openvswitch-agent restart
    service dnsmasq restart
    service apache2 restart
    service memcached restart
    service tgt stop
    service iscsi-network-interface restart
    service tgt start
}

function add_grizzly_repo()
{
    report_to_dialog "$title" "Install ubuntu-cloud-keyring..." 2
    force_install ubuntu-cloud-keyring >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install python-software-properties..." 3
    force_install python-software-properties >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install python-keyring..." 4
    force_install python-keyring >> ${LOG_FILE} 2>>${ERR_FILE}
}

function update_system()
{
    report_to_dialog "$title" "System update..." 5
    apt-get update >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "System upgrade..." 6
    apt-get -y --force-yes upgrade >> ${LOG_FILE} 2>>${ERR_FILE}
}

function install_dependency()
{
    report_to_dialog "$title" "Autoremove mysql-server-5.5..." 7
    apt-get autoremove --purge --yes mysql-server-5.5 >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Autoremove mysql-server..." 8
    apt-get autoremove --purge --yes mysql-server >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Autoremove mysql-common..." 9
    apt-get autoremove --purge --yes mysql-common >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove /var/lib/mysql..." 10
    rm -rf /var/lib/mysql  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove /etc/mysql..." 11
    sleep 1
    rm -rf /etc/mysql >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install mysql..." 12
    mysql_config >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install mysql-server..." 13
    force_install mysql-server  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install python-mysqldb..." 13
    force_install python-mysqldb  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Change mysql configuration..." 13
    sed -i "s/127.0.0.1/0.0.0.0/g" /etc/mysql/my.cnf  >> ${LOG_FILE} 2>>${ERR_FILE}
    sed -i "/^character_set_server/d" /etc/mysql/my.cnf  >> ${LOG_FILE} 2>>${ERR_FILE}
    sed -i "/^\[mysqld\]/a character_set_server=utf8" /etc/mysql/my.cnf  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Service mysql restart..." 13
    service mysql restart  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install mysql..." 13
    install_mysql  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install rabbitmq-server..." 14
    force_install rabbitmq-server >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install ntp..." 15
    force_install ntp >> ${LOG_FILE} 2>>${ERR_FILE}
cat <<EOF > /etc/ntp.conf
restrict default nomodify notrap noquery
restrict 127.0.0.1
restrict $ext_nic_ip mask 255.255.255.0 nomodify

server 127.127.1.0
fudge 127.127.1.0 stratum 10

driftfile /var/lib/ntp/ntp.drift
broadcastdelay 0.008
keys /etc/ntp/keys
EOF
    service ntp restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install bridge..." 16
    install_bridge >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install memcached..." 16
    force_install memcached >> ${LOG_FILE} 2>>${ERR_FILE}
    sed -i "s/127.0.0.1/$control_node_ip/g" /etc/memcached.conf
    report_to_dialog "$title" "Service memcached restart..." 16
    service memcached restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install python-memcache..." 17
    force_install python-memcache >> ${LOG_FILE} 2>>${ERR_FILE}
}


function mysql_config(){
cat <<MYSQL_PRESEED | debconf-set-selections
mysql-server-5.5 mysql-server/root_password password $mysql_passwd
mysql-server-5.5 mysql-server/root_password_again password $mysql_passwd
mysql-server-5.5 mysql-server/start_on_boot boolean true
MYSQL_PRESEED
}
function install_mysql()
{
    mysql -uroot -p$mysql_passwd -e "grant all privileges on *.* to 'root'@'%' identified by '$mysql_passwd' with grant option;"
    mysql -uroot -p$mysql_passwd -e "use mysql;delete from user where user='';"
    mysql -uroot -p$mysql_passwd -e "DROP DATABASE IF EXISTS nova;"
    mysql -uroot -p$mysql_passwd -e "CREATE DATABASE nova;"
    mysql -uroot -p$mysql_passwd -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$mysql_passwd';"
    mysql -uroot -p$mysql_passwd -e "DROP DATABASE IF EXISTS glance;"
    mysql -uroot -p$mysql_passwd -e "CREATE DATABASE glance;"
    mysql -uroot -p$mysql_passwd -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$mysql_passwd';"
    mysql -uroot -p$mysql_passwd -e "DROP DATABASE IF EXISTS keystone;"
    mysql -uroot -p$mysql_passwd -e "CREATE DATABASE keystone;"
    mysql -uroot -p$mysql_passwd -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$mysql_passwd';"
    mysql -uroot -p$mysql_passwd -e "DROP DATABASE IF EXISTS quantum;"
    mysql -uroot -p$mysql_passwd -e "CREATE DATABASE quantum;"
    mysql -uroot -p$mysql_passwd -e "GRANT ALL PRIVILEGES ON quantum.* TO 'quantum'@'%' IDENTIFIED BY '$mysql_passwd';"
    mysql -uroot -p$mysql_passwd -e "DROP DATABASE IF EXISTS cinder;"
    mysql -uroot -p$mysql_passwd -e "CREATE DATABASE cinder;"
    mysql -uroot -p$mysql_passwd -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$mysql_passwd';"
    mysql -uroot -p$mysql_passwd -e "DROP DATABASE IF EXISTS horizon;"
    mysql -uroot -p$mysql_passwd -e "CREATE DATABASE horizon;"
    mysql -uroot -p$mysql_passwd -e "GRANT ALL PRIVILEGES ON horizon.* TO 'horizon'@'%' IDENTIFIED BY '$mysql_passwd';"
    mysql -uroot -p$mysql_passwd -e "DROP DATABASE IF EXISTS creeper;"
    mysql -uroot -p$mysql_passwd -e "CREATE DATABASE creeper;"
    mysql -uroot -p$mysql_passwd -e "GRANT ALL PRIVILEGES ON creeper.* TO 'creeper'@'%' IDENTIFIED BY '$mysql_passwd';"
}

function install_bridge()
{
    force_install vlan bridge-utils
    sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/" /etc/sysctl.conf
    sysctl net.ipv4.ip_forward=1
}

function force_install()
{
    apt-get install -y --force-yes $@
}

function install_keystone()
{
    cp -r ./res/license /usr/lib/python2.7/dist-packages/ >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove authentication service." 17
    apt-get autoremove --purge --yes keystone >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove authentication service.." 17
    rm -rf /var/lib/keystone >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove authentication service..." 17
    rm -rf /etc/keystone >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install authentication service..." 17
    force_install keystone >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Set authentication configuration..." 18
    keystone_config >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Authentication restart..." 19
    service keystone restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Authentication-manage db_sync..." 20
    keystone-manage db_sync >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Source authentication..." 21
    set_up_openstack.sh >> ${LOG_FILE} 2>>${ERR_FILE}
}

function keystone_config(){
    mysql_passwd=${mysql_passwd:-"123456"}
    control_node_ip=${control_node_ip:-"127.0.0.1"}
    admin_token=${admin_token:-"123456"}
    sed -i "s/[# ]*connection[ ]*=.*/connection = mysql:\/\/keystone:$mysql_passwd@$control_node_ip\/keystone/g" /etc/keystone/keystone.conf    
    sed -i "s/[# ]*token_format[ ]*=.*/token_format = UUID/g" /etc/keystone/keystone.conf
    sed -i "s/[# ]*admin_token[ ]*=.*/admin_token = $admin_token/g" /etc/keystone/keystone.conf
    sed -i 's/# member_role_name = _member_/member_role_name = Member/g' /etc/keystone/keystone.conf
    #memcache
    sed -i "/bind_host/a  \memcached_servers = $control_node_ip:11211"  /etc/keystone/keystone.conf
    sed -i "s/keystone.token.backends.sql.Token/keystone.token.backends.memcache.Token/g" /etc/keystone/keystone.conf
    sed -i "/expiration/a \[memcache]" /etc/keystone/keystone.conf
    sed -i "/\[memcache\]/a \max_compare_and_set_retry = 1" /etc/keystone/keystone.conf
    sed -i "/\[memcache\]/a \servers = $control_node_ip:11211" /etc/keystone/keystone.conf
    cp -r ./res/keystone/* /usr/share/pyshared/keystone
}

function set_up_openstack.sh(){
    admin_token=${admin_token:-"123456"}
    cat <<ENV_AUTH > /etc/profile.d/openstack.sh
#! /bin/sh
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=ADMIN
export OS_AUTH_URL="http://localhost:5000/v2.0/"
export SERVICE_TOKEN=ADMIN
export SERVICE_ENDPOINT="http://localhost:35357/v2.0"
ENV_AUTH
    sed -i -e "s/ADMIN/$admin_token/g" /etc/profile.d/openstack.sh
    source /etc/profile.d/openstack.sh
}

function install_glance()
{
    report_to_dialog "$title" "Remove image service." 22
    apt-get autoremove --purge --yes glance  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove image service.." 22
    sleep 1
    rm -rf /var/lib/glance  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Remove image service..." 22
    rm -rf /etc/glance  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install image service..." 23
    force_install glance >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Set image service configuration..." 24
    glance_config >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Image service api restart..." 25
    service glance-api restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Image service registry restart..." 26
    service glance-registry restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Image service manage db_sync..." 27
    glance-manage db_sync >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Image service registry restart..." 28
    service glance-registry restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Image service api restart..." 29
    service glance-api restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Upload images please wait a moment..." 30
    sleep 5
    upload_images >> ${LOG_FILE} 2>>${ERR_FILE}
} 

function upload_images()
{
    if [[ -d img ]]; then
        for i in $( ls img | grep "\.img" )
        do
            glance --os-tenant-name service --os-username glance image-create \
                --name ${i%\.*} --is-public true --container-format ovf --min-disk 15 --min-ram 512\
                --disk-format qcow2 < "img/$i"
        done
    fi
}

function glance_config(){
    mysql_passwd=${mysql_passwd:-123456}
    control_node_ip=${control_node_ip:-localhost}
    admin_token=${admin_token:-123456}
    sed -i -e "
s/^auth_host =.*/auth_host = $control_node_ip/g;
s/^admin_tenant_name =.*/admin_tenant_name = service/g;
s/^admin_user =.*/admin_user = glance/g;
s/^admin_password =.*/admin_password = $admin_token/g;
" /etc/glance/glance-api.conf
    sed -i "/bind_host/a  \memcached_servers = $control_node_ip:11211"  /etc/glance/glance-api.conf
    sed -i -e "
s/^auth_host =.*/auth_host = $control_node_ip/g;
s/^admin_tenant_name =.*/admin_tenant_name = service/g;
s/^admin_user =.*/admin_user = glance/g;
s/^admin_password =.*/admin_password = $admin_token/g;
" /etc/glance/glance-registry.conf
    sed -i "/bind_host/a  \memcached_servers = $control_node_ip:11211"  /etc/glance/glance-registry.conf
    sed -i "s/^sql_connection[ ]*=.*/sql_connection = mysql:\/\/glance:$mysql_passwd@$control_node_ip\/glance/g" /etc/glance/glance-api.conf
    sed -i "s/[# ]*flavor[ ]*=/flavor = keystone/g" /etc/glance/glance-api.conf
    if ! grep -q "flavor = keystone" /etc/glance/glance-api.conf; then
        echo "flavor = keystone" >> /etc/glance/glance-api.conf
    fi
    sed -i "s/^sql_connection[ ]*=.*/sql_connection = mysql:\/\/glance:$mysql_passwd@$control_node_ip\/glance/g" /etc/glance/glance-registry.conf
    sed -i "s/[# ]*flavor[ ]*=/flavor = keystone/g" /etc/glance/glance-registry.conf
    if ! grep -q "flavor = keystone" /etc/glance/glance-registry.conf; then
        echo "flavor = keystone" >> /etc/glance/glance-registry.conf
    fi
    cp -r ./res/glance/* /usr/share/pyshared/glance/
    cp -r ./res/glanceclient/* /usr/share/pyshared/glanceclient/
}


function install_quantum()
{
    report_to_dialog "$title" "Remove openvswitch switch..." 31
    apt-get autoremove --purge -y openvswitch-switch >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove openvswitch datapath dkms..." 31
    apt-get autoremove --purge -y openvswitch-datapath-dkms >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual network service server..." 31
    apt-get autoremove --purge -y quantum-server >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual network service plugin openvswitch..." 31
    apt-get autoremove --purge -y quantum-plugin-openvswitch >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual network service plugin openvswitch-agent..." 31
    apt-get autoremove --purge -y quantum-plugin-openvswitch-agent >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove dnsmasq..." 31
    apt-get autoremove --purge -y dnsmasq >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual network service dhcp agent..." 31
    apt-get autoremove --purge -y quantum-dhcp-agent >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual network service l3 agent..." 31
    apt-get autoremove --purge -y quantum-l3-agent >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual network service configuration..." 31
    rm -rf /var/lib/quantum >> ${LOG_FILE} 2>>${ERR_FILE}
    rm -rf /etc/quantum >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install openvswitch datapath source..." 32
    force_install openvswitch-datapath-source >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install openvswitch-datapath..." 32
    module-assistant auto-install openvswitch-datapath >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install openvswitch-switch..." 32
    force_install openvswitch-switch >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install virtual network service brcompat..." 32
    force_install openvswitch-brcompat >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Sed openvswitch-switch..." 33
    sed -i 's/# BRCOMPAT=no/BRCOMPAT=yes/g' /etc/default/openvswitch-switch >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Service openvswitch-switch restart..." 34
    service openvswitch-switch restart >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 10
    service openvswitch-switch restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Add br-ex and br-int..." 35
    lsmod | grep brcompat >> ${LOG_FILE} 2>>${ERR_FILE}
    ovs-vsctl add-br br-int >> ${LOG_FILE} 2>>${ERR_FILE}
    ovs-vsctl add-br br-ex >> ${LOG_FILE} 2>>${ERR_FILE}
    #ovs-vsctl add-port br-ex eth0
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install Virtual network service-server..." 36
    force_install quantum-server >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install Virtual network service-plugin-openvswitch..." 37
    force_install quantum-plugin-openvswitch >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install Virtual network service-plugin-openvswitch-agent..." 38
    force_install quantum-plugin-openvswitch-agent >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install dnsmasq..." 39
    force_install dnsmasq >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install Virtual network service-dhcp-agent..." 40
    force_install quantum-dhcp-agent >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install Virtual network service-l3-agent..." 41
    force_install quantum-l3-agent >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Set Virtual network service configuration..." 42
    quantum_config >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Set dns configuration..." 43
    dns_config >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    echo "root_helper = sudo /usr/bin/quantum-rootwrap /etc/quantum/rootwrap.conf" >> /etc/quantum/dhcp_agent.ini 2>>${ERR_FILE}
    report_to_dialog "$title" "Virtual network service-server restart..." 44
    service quantum-server restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Virtual network service-l3-agent restart..." 45
    service quantum-l3-agent restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Virtual network service-dhcp-agent restart..." 46
    service quantum-dhcp-agent restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Virtual network service-metadata-agent restart..." 47
    service quantum-metadata-agent restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Virtual network service-plugin-openvswitch-agent restart..." 48
    service quantum-plugin-openvswitch-agent restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Service dnsmasq restart..." 49
    service dnsmasq restart >> ${LOG_FILE} 2>>${ERR_FILE}
    sed -i "/^exit 0/i\service dnsmasq restart\n" /etc/rc.local
    sleep 10
}

function quantum_config(){
    cp -r ./res/quantum/* /usr/share/pyshared/quantum
    sed -i -e "
s/^auth_host[ ]*=.*/auth_host = $control_node_ip/g;
s/^admin_tenant_name =.*/admin_tenant_name = service/g;
s/^admin_user =.*/admin_user = quantum/g;
s/^admin_password =.*/admin_password = $admin_token/g;
s/^root_helper =.*/root_helper = sudo \/usr\/bin\/quantum-rootwrap \/etc\/quantum\/rootwrap.conf/g;
" /etc/quantum/quantum.conf
    sed -i "/^\[QUOTAS\]/a quota_router = -1" /etc/quantum/quantum.conf
    sed -i "/bind_host/a  \memcached_servers = $control_node_ip:11211" /etc/quantum/quantum.conf
    sed -i "s/^sql_connection[ ]*=.*/sql_connection = mysql:\/\/quantum:$mysql_passwd@$control_node_ip\/quantum/g" /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
    safe_sed_ovs_quantum_plugin "tenant_network_type" "gre"
    safe_sed_ovs_quantum_plugin "tunnel_id_ranges" "1:1000"
    safe_sed_ovs_quantum_plugin "integration_bridge" "br-int"
    safe_sed_ovs_quantum_plugin "tunnel_bridge" "br-tun"
    safe_sed_ovs_quantum_plugin "local_ip" "$control_node_ip"
    safe_sed_ovs_quantum_plugin "enable_tunneling" "True"
    sed -i -e "
s/^auth_url =.*/ http:\/\/$control_node_ip:35357\/v2.0/g;
s/^admin_tenant_name =.*/admin_tenant_name = service/g;
s/^admin_user =.*/admin_user = quantum/g;
s/^admin_password =.*/admin_password = $admin_token/g;
s/# metadata_proxy_shared_secret =.*/metadata_proxy_shared_secret = $metadata/g;
" /etc/quantum/l3_agent.ini
    if ! grep -q "auth_url = " /etc/quantum/l3_agent.ini; then
        cat <<EOF  >> /etc/quantum/l3_agent.ini
auth_url = http://$control_node_ip:35357/v2.0/
admin_tenant_name = service
admin_user = quantum
admin_password = $admin_token
EOF
    fi
    sed -i -e "
s/^auth_url =.*/auth_url = http:\/\/$control_node_ip:35357\/v2.0/g;
s/^admin_tenant_name =.*/admin_tenant_name = service/g;
s/^admin_user =.*/admin_user = quantum/g;
s/^admin_password =.*/admin_password = $admin_token/g;
" /etc/quantum/metadata_agent.ini
}

function dns_config(){
    sed -i 's/#resolv-file=/resolv-file=\/etc\/resolv.dnsmasq.conf/g' /etc/dnsmasq.conf
    sed -i 's/#addn-hosts=.*/addn-hosts=\/etc\/dnsmasq.hosts/g' /etc/dnsmasq.conf
    echo "#add hostname in this new file" >> /etc/dnsmasq.hosts
    echo ${ext_nic_ip}" "${hostnm} >> /etc/dnsmasq.hosts
    cp /etc/resolv.conf /etc/resolv.dnsmasq.conf
    echo "nameserver "${ext_nic_ip} >> /etc/resolv.dnsmasq.conf
}

function safe_sed_ovs_quantum_plugin()
{
    if ! grep "^[ ]*$1[ ]*=" /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini ; then
        sed -i "/^\[OVS\]/a $1 = $2" /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
    else
        sed -i "s/^[ ]*$1[ ]*=.*/$1 = $2" /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
    fi
}

function libvirt_config(){
    admin_token=${admin_token:-123456}
    control_node_ip=${control_node_ip:-localhost}
    mysql_passwd=${mysql_passwd:-123456}
    # i know it is in this special format because purge_nova is called
    # so everything is fresh
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
    sed -i "s/[# ]*auth_tcp[ ]*=.*/auth_tcp = \"none\"/" /etc/libvirt/libvirtd.conf
    host_uuid=`python ./tools/host_uuid.py`
    sed -i -e "s/^#host_uuid =.*/host_uuid = \"$host_uuid\"/g;" /etc/libvirt/libvirtd.conf
    sed -i "s/[# ]*env libvirtd_opts[ ]*=.*/env libvirtd_opts=\"-d -l\"/g" /etc/init/libvirt-bin.conf
    sed -i "s/[# ]*libvirtd_opts[ ]*=.*/libvirtd_opts=\"-d -l\"/g" /etc/default/libvirt-bin
}

function nova_config(){
    sed -i -e "
s/^auth_host =.*/auth_host = $control_node_ip/;
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
rabbit_host=$control_node_ip
nova_url=http://$control_node_ip:8774/v1.1/
sql_connection=mysql://nova:$mysql_passwd@$control_node_ip/nova
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
memcached_servers=$control_node_ip:11211

# Auth
use_deprecated_auth=false
auth_strategy=keystone

# Imaging service
glance_api_servers=$control_node_ip:9292
image_service=nova.image.glance.GlanceImageService

# Vnc configuration
vnc_enabled=false
novncproxy_base_url=http://$ext_nic_ip:6080/vnc_auto.html
novncproxy_port=6080
vncserver_proxyclient_address=$control_node_ip
vncserver_listen=0.0.0.0

# Network settings
network_api_class=nova.network.quantumv2.api.API
quantum_url=http://$control_node_ip:9696
quantum_auth_strategy=keystone
quantum_admin_tenant_name=service
quantum_admin_username=quantum
quantum_admin_password=$admin_token
quantum_admin_auth_url=http://$control_node_ip:35357/v2.0
libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
linuxnet_interface_driver=nova.network.linux_net.LinuxOVSInterfaceDriver
firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver

#Metadata
service_quantum_metadata_proxy = True
quantum_metadata_proxy_shared_secret = $metadata
metadata_host = $control_node_ip
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
html5proxy_base_url=http://$ext_nic_ip:6082/spice_auto.html
server_listen=0.0.0.0
server_proxyclient_address=$ext_nic_ip

host_ip=$ext_nic_ip
my_ip=$control_node_ip
EOF
    #cat <<EOF >/etc/nova/nova-compute.conf
#[DEFAULT]
#libvirt_type=qemu
#libvirt_ovs_bridge=br-int
#libvirt_vif_type=ethernet
#libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
#libvirt_use_virtio_for_bridges=True
#EOF
}

function install_nova()
{
    report_to_dialog "$title" "Remove cpu-checker..." 66
    apt-get autoremove --purge --yes cpu-checker  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove kvm..." 66
    apt-get autoremove --purge --yes kvm  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove libvirt-bin..." 66
    apt-get autoremove --purge --yes libvirt-bin  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove pm-utils..." 66
    apt-get autoremove --purge --yes pm-utils  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual compute api..." 66
    apt-get autoremove --purge --yes nova-api  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual compute cert..." 66
    apt-get autoremove --purge --yes nova-cert  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual compute novnc..." 66
    apt-get autoremove --purge --yes novnc  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual compute consoleauth..." 66
    apt-get autoremove --purge --yes nova-consoleauth  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual compute scheduler..." 66
    apt-get autoremove --purge --yes nova-scheduler  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual compute novncproxy..." 66
    apt-get autoremove --purge --yes nova-novncproxy  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual compute doc..." 66
    apt-get autoremove --purge --yes nova-doc  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual compute conductor..." 66
    apt-get autoremove --purge --yes nova-conductor  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual compute kvm..." 66
    apt-get autoremove --purge --yes nova-compute-kvm  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove libvirt first configuration..." 66
    rm -rf /var/lib/libvirt  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove libvirt second configuration..." 66
    rm -rf /etc/libvirt  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual compute service first configuration..." 66
    rm -rf /var/lib/nova  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual compute service second configuration..." 66
    rm -rf /etc/nova  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    # install libvirt
    report_to_dialog "$title" "Install cpu-checker..." 67
    force_install cpu-checker >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "kvm-ok..." 68
    kvm-ok >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install kvm..." 69
    force_install kvm >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install libvirt-bin..." 70
    force_install libvirt-bin >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install pm-utils..." 71
    force_install pm-utils >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install virtual compute service configuration..." 72
    libvirt_config >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "service libvirt-bin restart" 72
    service libvirt-bin restart >> ${LOG_FILE} 2>>${ERR_FILE}
    # install nova
    report_to_dialog "$title" "Install virtual compute api..." 73
    force_install nova-api  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install virtual compute cert..." 74
    force_install nova-cert  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install virtual compute novnc..." 74
    force_install novnc  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install virtual compute consoleauth..." 74
    force_install nova-consoleauth  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install virtual compute scheduler..." 74
    force_install nova-scheduler  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install virtual compute novncproxy..." 74
    force_install nova-novncproxy  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install virtual compute doc..." 74
    force_install nova-doc  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install virtual compute conductor..." 74
    force_install nova-conductor  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Change Virtual compute-config..." 75
    nova_config  >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Hot patch Virtual compute..." 75
    hot_patch_nova  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Virtual compute-manage db sync..." 75
    nova-manage db sync >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Virtual compute all restart..." 76
    nova_all_restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Flavor customize..." 76
    nova --os-tenant-name service --os-username nova secgroup-add-rule default tcp 22 22 0.0.0.0/0  >> ${LOG_FILE} 2>>${ERR_FILE}
    nova --os-tenant-name service --os-username nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0  >> ${LOG_FILE} 2>>${ERR_FILE}
    flavor_customize >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Copy virtio-win-0.1-15.iso..." 77
    cp ./win/virtio-win-0.1-15.iso /var/lib/nova >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Copy virtio-WinXP-x86.vfd..." 78
    cp ./win/virtio-WinXP-x86.vfd /var/lib/nova >> ${LOG_FILE} 2>>${ERR_FILE}
}

function flavor_customize()
{
    nova-manage flavor delete --name=m1.tiny
    nova-manage flavor delete --name=m1.small
    nova-manage flavor delete --name=m1.medium
    nova-manage flavor delete --name=m1.large
    nova-manage flavor delete --name=m1.xlarge
    nova-manage flavor create \
        --name=vrv.tiny --memory=1024 --cpu=1 --root_gb=15 \
        --ephemeral_gb=0 --flavor=100 --swap=0
    nova-manage flavor create \
        --name=vrv.small --memory=2048 --cpu=1 --root_gb=20 \
        --ephemeral_gb=15 --flavor=101 --swap=0
    nova-manage flavor create \
        --name=vrv.medium --memory=4096 --cpu=2 --root_gb=40 \
        --ephemeral_gb=20 --flavor=102 --swap=0
    nova-manage flavor create \
        --name=vrv.large --memory=8192 --cpu=4 --root_gb=80 \
        --ephemeral_gb=40 --flavor=103 --swap=0
    nova-manage flavor create \
        --name=vrv.xlarge --memory=16384 --cpu=8 --root_gb=160 \
        --ephemeral_gb=80 --flavor=104 --swap=0
}

function nova_all_restart()
{
    pushd /etc/init.d
    for i in $( ls nova-* ); do service $i restart; done
    popd
}

function install_cinder()
{
    report_to_dialog "$title" "Remove virtual disk service api..." 51
    apt-get autoremove --purge --yes cinder-api >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual disk service scheduler..." 52
    apt-get autoremove --purge --yes cinder-scheduler >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove open-iscsi..." 52
    apt-get autoremove --purge --yes open-iscsi >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual disk service configuration..." 52
    rm -rf /var/lib/cinder >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Remove virtual disk service configuration..." 52
    rm -rf /etc/cinder >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install virtual disk service-api..." 53
    force_install cinder-api  >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install virtual disk service-scheduler..." 54
    force_install cinder-scheduler >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install open-iscsi..." 57
    force_install open-iscsi >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Set iscsi configuration..." 59
    iscsi_config >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Service open-iscsi restart..." 61
    service open-iscsi restart >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Set virtual disk service configuration..." 62
    cinder_config >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Virtual disk service-manage db sync..." 63
    cinder-manage db sync >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Service restart virtual disk service..." 65
    service_restart "cinder" >> ${LOG_FILE} 2>>${ERR_FILE} 
}

function iscsi_config(){
    cp -r ./res/cinder/* /usr/share/pyshared/cinder/
    ln -s /usr/share/pyshared/cinder/volume/resource_tracker.py /usr/lib/python2.7/dist-packages/cinder/volume/resource_tracker.py

    #replace using port 3260 from service tgt to ietd
    sed -i "/service tgt stop/d" /etc/rc.local
    sed -i "/service iscsi-network-interface restart/d" /etc/rc.local
    sed -i "/service tgt start/d" /etc/rc.local
    sed -i "/^exit 0/i\service tgt stop\nservice iscsi-network-interface restart\nservice tgt start\n" /etc/rc.local
    sed -i "s/false/true/g" /etc/default/iscsitarget
}

function cinder_config(){
    sed -i -e "
s/^auth_host =.*/auth_host = $control_node_ip/;
s/^admin_tenant_name =.*/admin_tenant_name = service/;
s/^admin_user =.*/admin_user = cinder/;
s/^admin_password =.*/admin_password = $admin_token/;
" /etc/cinder/api-paste.ini
echo "service: CommandFilter, /usr/bin/service, root" >> /etc/cinder/rootwrap.d/volume.filters
    cat <<EOF > /etc/cinder/cinder.conf
[DEFAULT]
rootwrap_config=/etc/cinder/rootwrap.conf
sql_connection = mysql://cinder:$mysql_passwd@$control_node_ip/cinder
api_paste_confg = /etc/cinder/api-paste.ini
iscsi_helper=ietadm
volume_name_template = volume-%s
volume_group = vrv-volumes
verbose = True
auth_strategy = keystone
#osapi_volume_listen_port=5900
my_ip=$control_node_ip
memcached_servers=$control_node_ip:11211
EOF
}
function service_restart()
{
    pushd /etc/init.d
    for i in $( ls $1* );
    do
        service $i restart
    done
    popd
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

function purge_horizon()
{
    apt-get autoremove --purge --yes openstack-dashboard
}

function install_horizon()
{
    report_to_dialog "$title" "Install management platform dashboard..." 88
    force_install openstack-dashboard >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install horizon configuration..." 89
    sed -i "s/[# ]*COMPRESS_OFFLINE[ ]*=.*/COMPRESS_OFFLINE = False/g" /etc/openstack-dashboard/local_settings.py >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Service apache2 restart..." 89
    service apache2 restart >> ${LOG_FILE} 2>>${ERR_FILE} 
}

function install_creeper()
{
    mysqladmin -uroot -p$mysql_passwd flush-hosts >> ${LOG_FILE} 2>>${ERR_FILE}
    rm -rf /usr/share/creeper >> ${LOG_FILE} 2>>${ERR_FILE}
    rm -rf /etc/apache2/conf.d/creeper.conf >> ${LOG_FILE} 2>>${ERR_FILE}
    sleep 1
    report_to_dialog "$title" "Install creeper step1..." 93
    cp ./creeper.tgz /tmp >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install creeper step2..." 95
    pushd /usr/share >> ${LOG_FILE} 2>>${ERR_FILE}
    tar xzf /tmp/creeper.tgz >> ${LOG_FILE} 2>>${ERR_FILE}
    chmod 777 ./creeper/creeper/doc -R >> ${LOG_FILE} 2>>${ERR_FILE}
    chmod 777 ./creeper/creeper/log_exports -R >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install creeper step3..." 97
    pushd creeper/tools >> ${LOG_FILE} 2>>${ERR_FILE}
    creeper_config >> ${LOG_FILE} 2>>${ERR_FILE}
    report_to_dialog "$title" "Install creeper step4..." 98
    . setup_creeper.sh >> ${LOG_FILE} 2>>${ERR_FILE}
    popd && popd >> ${LOG_FILE} 2>>${ERR_FILE}
}

function creeper_config(){
    if [ "$mysql_passwd" != "" ]; then
        sed -i "s/password/$mysql_passwd/g" env.rc
    fi
    if [ "$ext_nic_ip" != "" ]; then
        sed -i "s/192.168.0.2/$ext_nic_ip/g" env.rc
    fi
    if [ "$control_node_ip" != "" ]; then
        sed -i "s/127.0.0.1/$control_node_ip/g" env.rc
    fi
    if [ "$admin_token" != "" ]; then
        sed -i "s/OPENSTACK_ADMIN_TOKEN.*/OPENSTACK_ADMIN_TOKEN=$admin_token/g" env.rc
    fi
}

function hot_patch_nova()
{
    cp -r ./res/nova/* /usr/share/pyshared/nova/
    cp -r ./res/nova/etc/* /etc/
    rm -r /usr/share/pyshared/nova/etc/
    cp -r ./res/spice-html5 /usr/share/
    cp ./win/bg.png /usr/share/spice-html5
    ln -s /usr/share/pyshared/nova/scheduler/resource_tracker.py /usr/lib/python2.7/dist-packages/nova/scheduler/resource_tracker.py

    cp ./res/service/nova-spicehtml5proxy /usr/bin/
    chmod +x /usr/bin/nova-spicehtml5proxy
    cp ./res/service/nova-spicehtml5proxy.conf /etc/init/
    ln -s /lib/init/upstart-job /etc/init.d/nova-spicehtml5proxy

#    sed -i -e "s/l_host = .*/l_host = '$ext_nic_ip'/g;" ./res/spice_proxy/spice_proxy
#    cp ./res/spice_proxy/spice_proxy /usr/bin/
#    chmod +x /usr/bin/spice_proxy
#    cp ./res/spice_proxy/spice_proxy.conf /etc/init/
#    ln -s /lib/init/upstart-job /etc/init.d/spice_proxy

    sed -i -e "s/proxy_host=.*/proxy_host='$ext_nic_ip',/g;" ./res/creeper_proxy/creeper-proxy
    cp ./res/creeper_proxy/creeper-proxy /usr/bin/
    chmod +x /usr/bin/creeper-proxy
    cp ./res/creeper_proxy/creeper-proxy.conf /etc/init/
    ln -s /lib/init/upstart-job /etc/init.d/creeper-proxy

    link_path=/usr/lib/python2.7/dist-packages/nova/api/openstack/compute/contrib
    source_path=/usr/share/pyshared/nova/api/openstack/compute/contrib

    if [ ! -e $link_path/get_compute.py ]; then
        ln -s $source_path/get_compute.py $link_path/get_compute.py
    fi

    if [ ! -e $link_path/instance_network.py ]; then
        ln -s $source_path/instance_network.py $link_path/instance_network.py
    fi

    if [ ! -e $link_path/instance_state.py ]; then
        ln -s $source_path/instance_state.py $link_path/instance_state.py
    fi
    service creeper-proxy restart
}

# Author: Qinglong Meng
# Date: 2013-6-21
# Desc: monitor install
function install_monitor(){
    INSDIR=`pwd`
    cd ${INSDIR}/tools/nagios
    . nagios_ins.sh -c
    # FIXME: the control local or remote ip
    if [ -z "`grep -i ${ext_nic_ip} /etc/xinetd.d/nrpe`" ]; then
        sed -i "/only_from/{s/$/& ${ext_nic_ip}/}" /etc/xinetd.d/nrpe
        service xinetd restart
    fi
    cd ${INSDIR}
}

# Author: Qinglong Meng
# Date: 2013-6-25
# Desc: voyage install
function install_voyage(){
    INSDIR=`pwd`
    cd ${INSDIR}/tools/voyage
    . voyage_ins.sh
    cd ${INSDIR}
}
