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

CPE_EXEC="$KUBECTL exec -n $OSMNS $VCPE --"
WAN_EXEC="$KUBECTL exec -n $OSMNS $VWAN --"
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
PORTWAN=`$KUBECTL get -n $OSMNS -o jsonpath="{.spec.ports[0].nodePort}" service $WAN_SERV`
echo "PORTWAN = $PORTWAN"
PORTCTRL=`$KUBECTL get -n $OSMNS -o jsonpath="{.spec.ports[0].nodePort}" service $CTRL_SERV`
echo "PORTCTRL = $PORTCTRL"


# REQ 2. Add ctrl KNF
# 2. Config KNF Ctrl
echo "## 6. Configuramos red en nueva KNF CTRL, y levantamos controlador ryu"
# p2.1 p.6 (instantiation of ryu-manager)
# ???? preguntar que pasa cuando dos servicios tienen el 8080, 
# no veo manera de editar puertos ni en flow manager ni en rest_conf_switch....
# luego en el service de kubernetes lo hubiera expuesto...
$CTRL_EXEC service openvswitch-switch start
$CTRL_EXEC /usr/local/bin/ryu-manager /root/flowmanager/flowmanager.py ryu.app.rest_conf_switch ryu.app.ofctl_rest ryu.app.rest_qos /root/qos_simple_switch_13.py 2>&1 | tee logs/ryu.log &



## 3. En VNF:cpe agregar un bridge y sus vxlan - y añadir bridge openflow - y puntero a controlador
echo "## 2. En VNF:cpe agregar un bridge y configurar IPs y rutas"
$CPE_EXEC ip route add $IPWAN/32 via $K8SGW
$CPE_EXEC ovs-vsctl add-br brwan

# REQ 2. Add ctrl KNF
$CPE_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$CPE_EXEC ovs-vsctl set-fail-mode brwan secure
$CPE_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000002
$CPE_EXEC ovs-vsctl set-controller brwan tcp:$IPCTRL:6633

$CPE_EXEC ip link add cpewan type vxlan id 5 remote $IPWAN dstport 8741 dev eth0
$CPE_EXEC ovs-vsctl add-port brwan cpewan
$CPE_EXEC ifconfig cpewan up
$CPE_EXEC ip link add sr1sr2 type vxlan id 12 remote $REMOTESITE dstport 8742 dev net$NETNUM
$CPE_EXEC ovs-vsctl add-port brwan sr1sr2
$CPE_EXEC ifconfig sr1sr2 up



# # 4. En VNF:wan arrancar controlador SDN" - no se necesita - ahora va a CTRL
# echo "## 3. En VNF:wan arrancar controlador SDN"
# $WAN_EXEC /usr/local/bin/ryu-manager --verbose flowmanager/flowmanager.py ryu.app.ofctl_rest 2>&1 | tee ryu.log &
# $WAN_EXEC /usr/local/bin/ryu-manager ryu.app.simple_switch_13 ryu.app.ofctl_rest 2>&1 | tee ryu.log &
# $WAN_EXEC /usr/local/bin/ryu-manager flowmanager/flowmanager.py ryu.app.ofctl_rest 2>&1 | tee ryu.log &



## 4. En VNF:wan activar el modo SDN del conmutador y crear vxlan
# REQ. 1 - Substitute brwan switches as OpenFlow switches - esta hecho en sdwan
echo "## 4. En VNF:wan activar el modo SDN del conmutador y crear vxlan"
$WAN_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$WAN_EXEC ovs-vsctl set-fail-mode brwan secure
$WAN_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000001
$WAN_EXEC ovs-vsctl set-controller brwan tcp:$IPCTRL:6633
$WAN_EXEC ip link add cpewan type vxlan id 5 remote $IPCPE dstport 8741 dev eth0
$WAN_EXEC ovs-vsctl add-port brwan cpewan
$WAN_EXEC ifconfig cpewan up



# Connect wan to 
# $WAN_EXEC ip link add cpewan type vxlan id 5 remote $IPCPE dstport 8741 dev eth0
# ????? Conseguir conectividad en todo...
echo "## 7. a ver si puedo conectar con mpls"
$WAN_EXEC ovs-vsctl add-br voip
$WAN_EXEC ifconfig net$NETNUM $MPLSIN/24
$WAN_EXEC ip link add vxlan2 type vxlan id 2 remote $MPLSIPOUT  dev net$NETNUM
$WAN_EXEC ip link add axscpe type vxlan id 4 remote $IPWAN dev eth0
$WAN_EXEC ovs-vsctl add-port voip vxlan2
$WAN_EXEC ovs-vsctl add-port voip axscpe
$WAN_EXEC ifconfig vxlan2 up
$WAN_EXEC ifconfig axscpe up





# ## 5. Aplica las reglas de la sdwan con ryu
# REQ 2. Add ctrl KNF
echo "## 5. Aplica las reglas de la sdwan con ryu"
RYU_ADD_URL_CTRL="http://$IPCTRL:8080/stats/flowentry/add"
curl -X POST -d @json/from-cpe.json $RYU_ADD_URL_CTRL
curl -X POST -d @json/to-cpe.json $RYU_ADD_URL_CTRL
curl -X POST -d @json/broadcast-from-axs.json $RYU_ADD_URL_CTRL
curl -X POST -d @json/from-mpls.json $RYU_ADD_URL_CTRL
curl -X POST -d @json/to-voip-gw.json $RYU_ADD_URL_CTRL
curl -X POST -d @json/sdedge$NETNUM/to-voip.json $RYU_ADD_URL_CTRL



# ## 6. Add QoS!!
# REQ 4. Add QoS
ACC_DPID=0000000000000003
CONF_OVSDB="http://$IPCTRL:8080/v1.0/conf/switches/$ACC_DPID/ovsdb_addr"
curl -X PUT -d "\"tcp:$IPACC:6632\"" $CONF_OVSDB
curl -X POST -d @json_qos/to_voipgw.json http://$IPCTRL:8080/qos/rules/$ACC_DPID
curl -X POST -d @json_qos/qos.json http://$IPCTRL:8080/qos/queue/$ACC_DPID