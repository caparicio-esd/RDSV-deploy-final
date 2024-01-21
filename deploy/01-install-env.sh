#!/bin/bash

export LETTER=B
export OSM_USER=rdsv$LETTER
export OSM_PASSWORD=xxxx$LETTER
export OSM_PROJECT=rpry$LETTER
export OSM_HOSTNAME=10.11.13.1
export MY_IP=$( ifconfig | grep 10.11.13 | awk '{print $2}' )

# Start tunnel
echo "Installing..."
./bin/rdsv-start-tun $LETTER
./bin/rdsv-config-osmlab $LETTER

# Ensure $OSMNS variable
echo "Ensuring vars"
export OSM_USER=rdsv$LETTER
export OSM_PASSWORD=xxxx$LETTER
export OSM_PROJECT=rpry$LETTER
export OSM_HOSTNAME=10.11.13.1
export MY_IP=$( ifconfig | grep 10.11.13 | awk '{print $2}' )
export OSMNS=$( osm k8scluster-list --literal | awk '/projects_read/{getline;print $2}' )

echo "OSM_USER=${OSM_USER}"
echo "OSM_PASSWORD=${OSM_PASSWORD}"
echo "OSM_PROJECT=${OSM_PROJECT}"
echo "OSM_HOSTNAME=${OSM_HOSTNAME}"
echo "MY_IP=${MY_IP}"
echo "OSMNS=${OSMNS}"

# Check access networks
echo "Checking stuff with kubernetes"
microk8s kubectl get network-attachment-definitions -n $OSMNS
microk8s kubectl get all -n $OSMNS