#! /usr/bin/env bash

#ext_nic_ip=${ext_nic_ip:-"127.0.0.1"}
ext_net_cidr=${ext_nic_ip%\.*}.1/24
admin_subnet_cidr=10.0.${ext_nic_ip##*\.}.0/24
admin_subnet_gw=10.0.${ext_nic_ip##*\.}.1

function clear_quantum()
{
    admin_router_id=$(quantum --os-tenant-name service --os-username quantum router-list | awk '/ admin_router / {print $2}')
    admin_subnet_id=$(quantum --os-tenant-name service --os-username quantum subnet-list | awk '/ admin_subnet / {print $2}')
    if [[ $admin_router_id ]]; then
        quantum --os-tenant-name service --os-username quantum router-gateway-clear ${admin_router_id}
        quantum --os-tenant-name service --os-username quantum router-interface-delete ${admin_router_id} ${admin_subnet_id}
        quantum --os-tenant-name service --os-username quantum router-delete ${admin_router_id}
    fi
    if [[ $admin_subnet_id ]]; then
        quantum --os-tenant-name service --os-username quantum subnet-delete ${admin_subnet_id}
    fi
    admin_net_id=$(quantum --os-tenant-name service --os-username quantum net-list | awk '/ admin_net / {print $2}')
    if [[ $admin_net_id ]]; then
        quantum --os-tenant-name service --os-username quantum net-delete ${admin_net_id}
    fi
    ext_subnet_id=$(quantum --os-tenant-name service --os-username quantum subnet-list | awk '/ ext_subnet / {print $2}')
    if [[ $ext_subnet_id ]]; then
        quantum --os-tenant-name service --os-username quantum subnet-delete ${ext_subnet_id}
    fi
    ext_net_id=$(quantum --os-tenant-name service --os-username quantum net-list | awk '/ ext_net / {print $2}')
    if [[ $ext_net_id ]]; then
        quantum --os-tenant-name service --os-username quantum net-delete ${ext_net_id}
    fi
}

function init_quantum()
{
    ext_net_id=$(quantum --os-tenant-name service --os-username quantum net-create ext_net --router:external=True | awk '/ id / {print $4}')
    ext_subnet_id=$(quantum --os-tenant-name service --os-username quantum subnet-create ext_net ${ext_net_cidr} --name=ext_subnet --gateway_ip ${ext_gateway} --allocation-pool start=$start_ip_addr,end=$end_ip_addr --enable_dhcp=False | awk '/ id / {print $4}')

    admin_tenant_id=$(keystone tenant-list | awk '/ admin / {print $2}')
    admin_net_id=$(quantum --os-tenant-name service --os-username quantum net-create admin_net --tenant_id ${admin_tenant_id} | awk '/ id / {print $4}')
    admin_subnet_id=$(quantum --os-tenant-name service --os-username quantum subnet-create admin_net ${admin_subnet_cidr} --name=admin_subnet --gateway_ip ${admin_subnet_gw} --tenant_id ${admin_tenant_id} --dns-nameserver 8.8.8.8 | awk '/ id / {print $4}')

    admin_router_id=$(quantum --os-tenant-name service --os-username quantum router-create --tenant_id ${admin_tenant_id} admin_router | awk '/ id / {print $4}')
    quantum --os-tenant-name service --os-username quantum router-interface-add ${admin_router_id} ${admin_subnet_id}
    quantum --os-tenant-name service --os-username quantum router-gateway-set ${admin_router_id} ${ext_net_id}
}

clear_quantum
init_quantum
