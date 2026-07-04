#!/bin/bash

echo Running $0

function conn_customer_to_provider {
  local vrf="$1"
  local table_id="$2"
  local src="$3"
  local dst="$4"
  local mtu="$5"

  local lhs_if="v-$dst"
  local rhs_if="v-$src"

  ip -n "$src" l add "$vrf" type vrf table "$table_id"
  ip -n "$src" l set "$vrf" up

  ip l add "$lhs_if" netns "$src" type veth peer "$rhs_if" netns "$dst"
  ip -n "$src" l set "$lhs_if" vrf "$vrf"
  ip -n "$src" l set "$lhs_if" mtu "$mtu"
  ip -n "$dst" l set "$rhs_if" mtu "$mtu"
  ip -n "$src" l set "$lhs_if" up
  ip -n "$dst" l set "$rhs_if" up
}

# note: vrf/table_id is local to router so they are reusable global-wide

conn_customer_to_provider ce1 1001 pe1 ce1 1280
conn_customer_to_provider ce3 1002 pe1 ce3 1280
conn_customer_to_provider ce5 1003 pe1 ce5 1280

conn_customer_to_provider ce2 1001 pe2 ce2 1280
conn_customer_to_provider ce4 1002 pe2 ce4 1280
conn_customer_to_provider ce6 1003 pe2 ce6 1280

# you can test them via:
# ip netns exec ce1 ping ff02::1%v-pe1
# ip netns exec ce3 ping ff02::1%v-pe1
# ip netns exec ce2 ping ff02::1%v-pe2
# ip netns exec ce4 ping ff02::1%v-pe2

# ce1 and ce2 belong to the same organization, and ce3 and ce4 belong to the same org.
# the private address allocations are:
# org 1:
# ce1: 10.0.0.0/24
# ce2: 10.0.1.0/24
# org 2:
# ce3: 10.0.0.0/24
# ce4: 10.0.1.0/24
# ce1 (connected to pe1) wants to have access to ce2 (connected to pe2) and vice versa,
# ce3 (connected to pe1) wants to have access to ce4 (connected to pe2) and vice versa.
#
# ce1, ce3 would use the first usable host address in 10.0.0.0/30 to interconnect with pe1
# ce2, ce4 would use the first usable host address in 10.0.1.0/30 to interconnect with pe2



function assign_ce_interconnect {
  local pe=$1
  local ce=$2
  local pe_addr=$3
  local ce_addr=$4
  local ce_lo=$5
  local ptp_mask=$6

  local ce_intf="v-$ce"
  local pe_intf="v-$pe"

  # assign ptp addresses to both sides
  ip -n $pe address add "$pe_addr/$ptp_mask" dev "$ce_intf"
  ip -n $ce address add "$ce_addr" dev "$pe_intf"

  # assign lo
  ip -n $ce address add $ce_lo dev lo

  # assign default gw (at customer side)
  ip -n $ce route add default via $pe_addr
}

assign_ce_interconnect pe1 ce1 10.0.0.2 10.0.0.1/30 10.0.0.0/24 30
assign_ce_interconnect pe1 ce3 10.0.0.2 10.0.0.1/30 10.0.0.0/24 30

assign_ce_interconnect pe1 ce1 fd00:1::1 fd00:1::/127 fd00:1::/48 127
assign_ce_interconnect pe1 ce3 fd00:1::1 fd00:1::/127 fd00:1::/48 127

assign_ce_interconnect pe2 ce2 10.0.1.2 10.0.1.1/30 10.0.1.0/24 30
assign_ce_interconnect pe2 ce4 10.0.1.2 10.0.1.1/30 10.0.1.0/24 30

assign_ce_interconnect pe2 ce2 fd00:1:1::1 fd00:1:1::/127 fd00:1:1::/48 127
assign_ce_interconnect pe2 ce4 fd00:1:1::1 fd00:1:1::/127 fd00:1:1::/48 127

function assign_ptp_interconnect {
  local pe=$1
  local ce=$2
  local pe_addr=$3
  local ce_addr=$4
  local ce_lo=$5

  local ce_intf="v-$ce"
  local pe_intf="v-$pe"

  # assign ptp addresses to both sides
  ip -n $pe address add "$pe_addr" dev "$ce_intf"
  ip -n $ce address add "$ce_addr" dev "$pe_intf"

  # assign lo
  ip -n $ce address add $ce_lo dev lo
}

assign_ptp_interconnect pe1 ce5 fd00:1::1/127 fd00:1::/127 fd00:1::/128
assign_ptp_interconnect pe1 ce5 10.0.0.2/30 10.0.0.1/30 10.0.0.4/32
assign_ptp_interconnect pe2 ce6 fd00:1:1::1/127 fd00:1:1::/127 fd00:1:1::/128
assign_ptp_interconnect pe2 ce6 10.0.1.2/30 10.0.1.1/30 10.0.1.4/32

# assign route to ce
function assign_ce_route {
  local pe=$1
  local ce_vrf="$2"
  local ce="$3"
  local ce_subnet="$4"
  local ce_endpoint="$5"

  ip -n "$pe" route add "$ce_subnet" via "$ce_endpoint" vrf "$ce_vrf"
}

# add reverse routes to tell PE how to reach CE

assign_ce_route pe1 ce1 ce1 10.0.0.0/24 10.0.0.1
assign_ce_route pe1 ce3 ce3 10.0.0.0/24 10.0.0.1
assign_ce_route pe2 ce2 ce2 10.0.1.0/24 10.0.1.1
assign_ce_route pe2 ce4 ce4 10.0.1.0/24 10.0.1.1

assign_ce_route pe1 ce1 ce1 fd00:1::/48 fd00:1::
assign_ce_route pe1 ce3 ce3 fd00:1::/48 fd00:1::
assign_ce_route pe2 ce2 ce2 fd00:1:1::/48 fd00:1:1::
assign_ce_route pe2 ce4 ce4 fd00:1:1::/48 fd00:1:1::

# for ce5, ce6, they use BGP, so no static routes would configure for them
