#!/bin/bash

MY_IP=$( ifconfig | grep 10.11.13 | awk '{print $2}' )
# OSMNS=$( osm k8scluster-list --literal | awk '/projects_read/{getline;print $2}' )
source ~/.bashrc

echo "OSM_USER=${OSM_USER}"
echo "OSM_PASSWORD=${OSM_PASSWORD}"
echo "OSM_PROJECT=${OSM_PROJECT}"
echo "OSM_HOSTNAME=${OSM_HOSTNAME}"
echo "MY_IP=${MY_IP}"
echo "OSMNS=${OSMNS}"

# Check switches
sudo ovs-vsctl show
microk8s kubectl get network-attachment-definitions -n $OSMNS

# IMPORTANT!!!!
# At this point VNX rootfs should have been changed. Please follow tutorial in README - 
# This is importante for installing arpwatch and iperf3

# Setup whole VNX scenario
sudo vnx -f $HOME/shared/rdsv-final/vnx/sdedge_nfv.xml -t