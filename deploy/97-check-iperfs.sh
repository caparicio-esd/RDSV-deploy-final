# set from h1 to voip-gw to check connectivity
# https://github.com/giros-dit/vnx-qos-ryu

# in h1 o h2
iperf3 -c 10.20.0.254 -p 5005 -u -b 3M


# in voip-gw
iperf3 -s -p 5005
