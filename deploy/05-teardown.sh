#!/bin/bash
source ~/.bashrc

echo "Deleting network services 1 and 2"
osm ns-delete corpcpe1
osm ns-delete corpcpe2

echo "wait up all down, then Ctrl+C"
watch microk8s kubectl get all -n $OSMNS
# wait up all down, then Ctrl+C

echo "Deleting nsds and vnfds"
osm nsd-delete corpcpe
osm vnfd-delete accessknf
osm vnfd-delete cpeknf
osm vnfd-delete ctrlknf
osm vnfd-delete wanknf

echo "bye!"
echo "(apruébennos, please....)"
