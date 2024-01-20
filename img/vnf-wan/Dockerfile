FROM caparicioesd/vnf-access
# install required packages
RUN apt-get clean
RUN apt-get update \
    && apt-get install -y \
    iptables 

COPY ./README.md ./README.md 