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


# Deploy scenarios
export NSID1=$(osm ns-create --ns_name corpcpe1 --nsd_name corpcpe --vim_account dummy_vim)
echo "wait up all are running, then Ctrl+C"
watch microk8s kubectl get all -n $OSMNS
# wait up all are running, then Ctrl+C

export NSID2=$(osm ns-create --ns_name corpcpe2 --nsd_name corpcpe --vim_account dummy_vim)
echo "wait up all are running again, then Ctrl+C"
watch microk8s kubectl get all -n $OSMNS
# wait up all are running, then Ctrl+C


# Config all scenarios
./sdedge1.sh
./sdedge2.sh
./sdwan1.sh
./sdwan2.sh
