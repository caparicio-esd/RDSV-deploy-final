#!/bin/bash
source ~/.bashrc

osm ns-delete corpcpe1
osm ns-delete corpcpe2

echo "wait up all down, then Ctrl+C"
watch microk8s kubectl get all -n $OSMNS
# wait up all down, then Ctrl+C