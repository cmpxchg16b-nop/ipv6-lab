#!/bin/bash

echo Running $0

for ns in pe1 p11 p12 p13 p21 p22 p23 p31 p32 p33 pe2; do
  echo create $ns
  ip netns add $ns
  ip -n $ns l set lo up
  ip netns exec $ns sysctl -w net.ipv6.conf.default.forwarding=1
  ip netns exec $ns sysctl -w net.ipv6.conf.all.forwarding=1
  ip netns exec $ns sysctl -w net.vrf.strict_mode=1
  ip netns exec $ns sysctl -w net.ipv6.conf.all.seg6_enabled=1
  ip netns exec $ns sysctl -w net.ipv6.conf.default.seg6_enabled=1
  ip netns exec $ns sysctl -w net.ipv6.conf.all.seg6_require_hmac=0
  ip netns exec $ns sysctl -w net.ipv6.conf.default.seg6_require_hmac=0
  ip netns exec $ns sysctl -w net.ipv6.conf.all.keep_addr_on_down=1
  ip netns exec $ns sysctl -w net.ipv6.conf.default.keep_addr_on_down=1
done

# vrf table id: 100 - 999 for ours
# 1000-1999 for customers

for ns in pe1 pe2; do
  echo create vrf srv6 in $ns
  ip -n $ns l add srv6 type vrf table 101
  ip -n $ns l set srv6 up
done
