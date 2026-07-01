#!/bin/bash

echo Running $0

for ns in pe1 p11 p12 p13 p21 p22 p23 p31 p32 p33 pe2; do
  container="frr-$ns"
  echo Launch $container
  podman run \
    --name $container \
    --hostname $ns \
    -v ./nodes/$ns/frr.conf.d:/etc/frr \
    -d \
    --cap-add cap_net_bind_service \
    --cap-add cap_net_admin \
    --cap-add cap_net_raw \
    --cap-add cap_sys_admin \
    --rm \
    --network ns:/run/netns/$ns \
    frrouting/frr:10.6.1
done
