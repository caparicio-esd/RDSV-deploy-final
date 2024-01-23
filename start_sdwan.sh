#!/bin/bash

# Requires the following variables
# KUBECTL: kubectl command
# OSMNS: OSM namespace in the cluster vim
# NETNUM: used to select external networks
# VCPE: "pod_id" or "deploy/deployment_id" of the cpd vnf
# VWAN: "pod_id" or "deploy/deployment_id" of the wan vnf
# REMOTESITE: the "public" IP of the remote site

set -u # to verify variables are defined
: $KUBECTL
: $OSMNS
: $NETNUM
: $VCPE
: $VWAN
: $VCTRL
: $REMOTESITE

if [[ ! $VCPE =~ "sdedge-ns-repo-cpechart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <cpe_deployment_id>: $VCPE"
    exit 1
fi
if [[ ! $VWAN =~ "sdedge-ns-repo-wanchart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <wan_deployment_id>: $VWAN"
    exit 1
fi
if [[ ! $VCTRL =~ "sdedge-ns-repo-ctrlchart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <ctrl_deployment_id>: $VCTRL"
    exit 1
fi

CPE_EXEC="$KUBECTL exec -n $OSMNS $VCPE --"
WAN_EXEC="$KUBECTL exec -n $OSMNS $VWAN --"
ACC_EXEC="$KUBECTL exec -n $OSMNS $VACC --"
CTRL_EXEC="$KUBECTL exec -n $OSMNS $VCTRL --"
WAN_SERV="${VWAN/deploy\//}"
CTRL_SERV="${VCTRL/deploy\//}"

# Router por defecto inicial en k8s (calico)
K8SGW="169.254.1.1"

## 1. Obtener IPs y puertos de las VNFs
echo "## 1. Obtener IPs y puertos de las VNFs"

IPCPE=`$CPE_EXEC hostname -I | awk '{print $1}'`
echo "IPCPE = $IPCPE"
IPWAN=`$WAN_EXEC hostname -I | awk '{print $1}'`
echo "IPWAN = $IPWAN"
IPCTRL=`$CTRL_EXEC hostname -I | awk '{print $1}'`
echo "IPCTRL = $IPCTRL"
IPACC=`$ACC_EXEC hostname -I | awk '{print $1}'`
echo "IPACC = $IPACC"
PORTCTRL=`$KUBECTL get -n $OSMNS -o jsonpath="{.spec.ports[0].nodePort}" service $CTRL_SERV`
echo "PORTCTRL = $PORTCTRL"
PORTWAN=`$KUBECTL get -n $OSMNS -o jsonpath="{.spec.ports[0].nodePort}" service $WAN_SERV`
echo "PORTWAN = $PORTWAN"


# REQ 2. Add ctrl KNF
# 2. Config KNF Ctrl
echo "## 6. Configuramos red en nueva KNF CTRL, y levantamos controlador ryu"
# p2.1 p.6 (instantiation of ryu-manager)
# no veo manera de editar puertos ni en flow manager ni en rest_conf_switch....
# luego en el service de kubernetes lo hubiera expuesto...
$CTRL_EXEC service openvswitch-switch start
$CTRL_EXEC /usr/local/bin/ryu-manager flowmanager/flowmanager.py ryu.app.rest_conf_switch ryu.app.ofctl_rest ryu.app.rest_qos qos_simple_switch_13.py 2>&1 | tee logs/ryu.log &


# REQ. 1 - Substitute brwan switches as OpenFlow switches - esta hecho en sdwan
# aquí estaba el problema de conectividad
$ACC_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$ACC_EXEC ovs-vsctl set-fail-mode brwan secure
$ACC_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000003
$ACC_EXEC ovs-vsctl set-controller brwan tcp:$IPCTRL:6633
$ACC_EXEC ovs-vsctl set-manager ptcp:6632


## 3. En VNF:cpe agregar un bridge y sus vxlan - y añadir bridge openflow - y puntero a controlador
echo "## 2. En VNF:cpe agregar un bridge y configurar IPs y rutas"
$CPE_EXEC ip route add $IPWAN/32 via $K8SGW

# REQ 2. Add ctrl KNF
$CPE_EXEC ovs-vsctl add-br brwan
# REQ. 1 - Substitute brwan switches as OpenFlow switches - esta hecho en sdwan
$CPE_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$CPE_EXEC ovs-vsctl set-fail-mode brwan secure
$CPE_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000002
$CPE_EXEC ovs-vsctl set-controller brwan tcp:$IPCTRL:6633
$CPE_EXEC ovs-vsctl set-manager ptcp:6632
$CPE_EXEC ip link add cpewan type vxlan id 5 remote $IPWAN dstport 8741 dev eth0
$CPE_EXEC ovs-vsctl add-port brwan cpewan
$CPE_EXEC ifconfig cpewan up
$CPE_EXEC ip link add sr1sr2 type vxlan id 12 remote $REMOTESITE dstport 8742 dev net$NETNUM
$CPE_EXEC ovs-vsctl add-port brwan sr1sr2
$CPE_EXEC ifconfig sr1sr2 up



# # x. En VNF:wan arrancar controlador SDN" - no se necesita - ahora va a CTRL
# echo "## 3. En VNF:wan arrancar controlador SDN"
# $WAN_EXEC /usr/local/bin/ryu-manager --verbose flowmanager/flowmanager.py ryu.app.ofctl_rest 2>&1 | tee ryu.log &
# $WAN_EXEC /usr/local/bin/ryu-manager ryu.app.simple_switch_13 ryu.app.ofctl_rest 2>&1 | tee ryu.log &
# $WAN_EXEC /usr/local/bin/ryu-manager flowmanager/flowmanager.py ryu.app.ofctl_rest 2>&1 | tee ryu.log &



## 4. En VNF:wan activar el modo SDN del conmutador y crear vxlan
# REQ. 1 - Substitute brwan switches as OpenFlow switches
echo "## 4. En VNF:wan activar el modo SDN del conmutador y crear vxlan"
$WAN_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$WAN_EXEC ovs-vsctl set-fail-mode brwan secure
$WAN_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000001
$WAN_EXEC ovs-vsctl set-controller brwan tcp:$IPCTRL:6633
$WAN_EXEC ovs-vsctl set-manager ptcp:6632
$WAN_EXEC ip link add cpewan type vxlan id 5 remote $IPCPE dstport 8741 dev eth0
$WAN_EXEC ovs-vsctl add-port brwan cpewan
$WAN_EXEC ifconfig cpewan up


## 5. Aplica las reglas de la sdwan con ryu
echo "## 5. Aplica las reglas de la sdwan con ryu"
RYU_ADD_URL="http://localhost:$PORTCTRL/stats/flowentry/add"
curl -X POST -d @json/from-cpe.json $RYU_ADD_URL
curl -X POST -d @json/to-cpe.json $RYU_ADD_URL
curl -X POST -d @json/broadcast-from-axs.json $RYU_ADD_URL
curl -X POST -d @json/from-mpls.json $RYU_ADD_URL
curl -X POST -d @json/to-voip-gw.json $RYU_ADD_URL
curl -X POST -d @json/sdedge$NETNUM/to-voip.json $RYU_ADD_URL



## 6. Qos
echo "## Applying QoS rules"
ACC_DPID=0000000000000003
curl -X PUT -d "\"tcp:$IPACC:6632\"" http://$IPCTRL:8080/v1.0/conf/switches/$ACC_DPID/ovsdb_addr
curl -X POST -d @json/to-voip-gw-qos.json http://$IPCTRL:8080/qos/rules/$ACC_DPID
curl -X POST -d @json/qos-rule-b.json http://$IPCTRL:8080/qos/queue/$ACC_DPID

