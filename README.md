# RDSV Practica final

## Fases
- Environment init
- Docker images and Helm charts
- Helm Repo and OSM connection index.yaml
- VNX specs modification for arpwatch
- Brwan switches sustitution
- KNF ctrl SDN Controller and connection to old switches

## Participantes
- Carlos Aparicio de Santiago
- Enzo Banchon Franco
- Manfredonio Nguema Ondo

## Scripts para entorno
### 01. Levantar Tunnel con 10.1.13.1
``` bash
./bin/rdsv-start-tun B
```
### 02. Levantar el entorno kubernetes, vim y conectarlo con OSM
En una pestaña diferente
``` bash
./bin/rdsv-config-osmlab B
```
En este punto ya esta desplegado el entorno
### 03. Creamos helm-repo chart
``` bash
./deploy/02-helm-charts.sh
```
### 04. Hacemos modificacion de entorno VNX - y levantamos VNX
Importante, antes hacer modificaciones en vnx rootfs
``` bash
vnx --modify-rootfs /usr/share/vnx/filesystems/vnx_rootfs_lxc_ubuntu64-20.04-v025-vnxlab/
```
Sale una consola de modificacion del filesystem de arranque de vnx. En esta consola: 
``` bash
apt-get update
apt-get install arpwatch iperf3 arpwatch -y
halt -p
```
Ahora ya podemos levantar el entorno
``` bash
./deploy/03-vnx-setup.sh
```
### 05. Despliegue de sdedge y sdwan 1 y 2
Ahora levantamos las redes en kubernetes y las configuramos
``` bash
./deploy/04-deploy-scenario.sh
```
### 06. Tirar el escenario abajo
Ahora levantamos las redes en kubernetes y las configuramos
``` bash
./deploy/05-teardown.sh
```