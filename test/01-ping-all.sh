#!/bin/bash

# format: <domain_id>:<region_id(8bits)><node_id(8bits)>
function make_address {
  local domain_id=$1
  local region_id=$2
  local node_id=$3
  local uniq_node_id=$(( (region_id << 8) + node_id ))
  printf "%s:%x" $domain_id $uniq_node_id
}

domain_global="2001:db8:1"

sleep 3

pe1=$(make_address $domain_global 1 1)
pe2=$(make_address $domain_global 5 1)

ip netns exec pe1 ip vrf exec srv6 ping -c1 "${pe1}::"
ip netns exec pe1 ip vrf exec srv6 ping -c1 "${pe2}::"

NROWS=3
NCOLS=3
for (( col=2; col<=NCOLS+1; col++ )) do
  for (( row=1; row<=NROWS; row++ )) do
    dst_addr=$(make_address $domain_global $col $row)
    ip netns exec pe1 ip vrf exec srv6 ping -c1 "${dst_addr}::"
  done
done

# test SRv6 encapsulation with statically programmed control-plane
ip netns exec ce1 ping -c10 10.0.1.4
ip netns exec ce3 ping -c10 10.0.1.4
ip netns exec ce1 ping -c10 fd00:1:1::
ip netns exec ce3 ping -c10 fd00:1:1::

# test SRv6 encapsulation and BGP L3VPN
ip netns exec ce5 ping -c3 10.0.1.4
ip netns exec ce5 ping -c3 fd00:1:1::
