#!/bin/bash

podman run \
  --name dn42 \
  -v ./frr.conf.d:/etc/frr \
  -d \
  --cap-add cap_net_bind_service \
  --cap-add cap_net_admin \
  --cap-add cap_net_raw \
  --cap-add cap_sys_admin \
  --rm \
  -it \
  --network ns:/run/netns/dn42 \
  frrouting/frr:10.6.1
