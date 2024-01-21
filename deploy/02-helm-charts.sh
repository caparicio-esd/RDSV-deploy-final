#!/bin/bash

# Ensure $OSMNS variable
# echo "Ensuring vars"
# export OSM_USER=rdsv$LETTER
# export OSM_PASSWORD=xxxx$LETTER
# export OSM_PROJECT=rpry$LETTER
# export OSM_HOSTNAME=10.11.13.1
MY_IP=$( ifconfig | grep 10.11.13 | awk '{print $2}' )
# OSMNS=$( osm k8scluster-list --literal | awk '/projects_read/{getline;print $2}' )
source ~/.bashrc

echo "OSM_USER=${OSM_USER}"
echo "OSM_PASSWORD=${OSM_PASSWORD}"
echo "OSM_PROJECT=${OSM_PROJECT}"
echo "OSM_HOSTNAME=${OSM_HOSTNAME}"
echo "MY_IP=${MY_IP}"
echo "OSMNS=${OSMNS}"

# Bajamos helm script
echo "Configurando helm repo"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Empaquetamos charts
mkdir $HOME/helm-files
cd ~/helm-files
helm package ~/shared/rdsv-final/helm/accesschart
helm package ~/shared/rdsv-final/helm/cpechart
helm package ~/shared/rdsv-final/helm/wanchart
helm package ~/shared/rdsv-final/helm/ctrlchart

# Creamos index.yaml
helm repo index --url http://$MY_IP/ .
cat index.yaml

# Tiramos docker helm-repo y lo volvemos a levantar
docker stop helm-repo
docker rm helm-repo
docker run --restart always --name helm-repo -p 80:80 -v ~/helm-files:/usr/share/nginx/html:ro -d nginx
sleep 10
curl http://$MY_IP/index.yaml

# Llevamos repo a OSM
osm repo-delete sdedge-ns-repo
osm repo-list
osm repo-add --type helm-chart --description "rdsvB repo" sdedge-ns-repo http://$MY_IP

# Instalar los vnfd y nsd
osm nsd-delete corpcpe
osm vnfd-delete accessknf
osm vnfd-delete cpeknf
osm vnfd-delete wanknf
osm vnfd-delete ctrlknf

osm vnfd-create $HOME/shared/rdsv-final/pck/accessknf_vnfd.tar.gz
osm vnfd-create $HOME/shared/rdsv-final/pck/cpeknf_vnfd.tar.gz
osm vnfd-create $HOME/shared/rdsv-final/pck/wanknf_vnfd.tar.gz
osm vnfd-create $HOME/shared/rdsv-final/pck/ctrlknf_vnfd.tar.gz
osm nsd-create  $HOME/shared/rdsv-final/pck/corpcpe_nsd.tar.gz
