#!/bin/bash

echo Running $0

for ns in ce1 ce2 ce3 ce4; do
  echo create $ns
  ip netns add $ns
  ip -n $ns l set lo up
  ip netns exec $ns sysctl -w net.ipv6.conf.default.forwarding=1
  ip netns exec $ns sysctl -w net.ipv6.conf.all.forwarding=1
  ip netns exec $ns sysctl -w net.ipv6.conf.all.keep_addr_on_down=1
  ip netns exec $ns sysctl -w net.ipv6.conf.default.keep_addr_on_down=1
done
