#!/bin/bash

echo Running $0

for ns in pe1 p11 p12 p13 p21 p22 p23 p31 p32 p33 pe2; do
  echo create $ns
  ip netns add $ns
  ip -n $ns l set lo up
  ip netns exec $ns sysctl -w net.ipv6.conf.default.forwarding=1
  ip netns exec $ns sysctl -w net.ipv6.conf.all.forwarding=1
done
