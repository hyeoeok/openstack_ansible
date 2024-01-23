#!/bin/bash
OCTAVIA_MGMT_SUBNET=172.16.0.0/12
OCTAVIA_MGMT_SUBNET_START=172.16.0.100
OCTAVIA_MGMT_SUBNET_END=172.16.31.254
OCTAVIA_MGMT_PORT_IP=172.16.0.4

export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD="cloud1234"
export OS_AUTH_URL=http://192.168.20.163:15000/v3/
export OS_CACERT="/opt/certificate/haproxy-internal.pem"
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export OS_INTERFACE=internal

#sudo mkdir -m755 -p /etc/dhcp/octavia
#sudo cp /etc/dhcp/dhclient.conf /etc/dhcp/octavia

SUBNET_ID=`openstack subnet show lb-mgmt-subnet -f value -c id`
PORT_FIXED_IP="--fixed-ip subnet=$SUBNET_ID,ip-address=$OCTAVIA_MGMT_PORT_IP"

MGMT_PORT=`openstack port list | grep octavia-health-manager-listen-port3`

if [ -n "$MGMT_PORT" ]
then
        MGMT_PORT_MAC=`openstack port show -c mac_address -f value octavia-health-manager-listen-port3`
        MGMT_PORT_ID=`openstack port show -c id -f value octavia-health-manager-listen-port3`
else
        MGMT_PORT_ID=`openstack port create --security-group lb-health-mgr-sec-grp --device-owner octavia:health-mgr \
         --host=$(hostname) -c id -f value --network lb-mgmt-net \
        $PORT_FIXED_IP octavia-health-manager-listen-port3`

        MGMT_PORT_MAC=`openstack port show -c mac_address -f value \
        $MGMT_PORT_ID`
fi

NETID=`openstack network show lb-mgmt-net -c id -f value`

OVS_PORT=`ovs-vsctl show | grep hm0`
if [ -n "$OVS_PORT" ]
then
        sleep 1
else
        ovs-vsctl add-port br-int o-hm0 \
        -- set Interface o-hm0 type=internal \
        -- set Interface o-hm0 external-ids:iface-status=active \
        -- set Interface o-hm0 external-ids:attached-mac=$MGMT_PORT_MAC \
        -- set Interface o-hm0 external-ids:iface-id=$MGMT_PORT_ID
fi

sudo ip link set dev o-hm0 address $MGMT_PORT_MAC
sudo iptables -I INPUT -i o-hm0 -p udp --dport 5555 -j ACCEPT
sudo dhclient -v o-hm0
