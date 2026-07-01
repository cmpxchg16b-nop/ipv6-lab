#!/bin/bash

echo Running $0

# -----------------------------------------------------------------------------
# SRv6 L3VPN: ingress PE steering / encapsulation routes.
#
# This script installs the seg6 encap routes into the customer VRFs on the PEs.
# mode encap wraps the inner IPv4 packet in an outer IPv6/SRH whose DA is the
# first SID of the list; transit End SIDs (if any) are consumed along the way,
# and the last SID is the egress PE's End.DT4 (decap). The outer packet is emitted
# via the srv6 VRF (table 101) for transport across the OSPFv3 underlay.
#
# The local SIDs (End.DT4 on PEs, End on P-routers) this steering relies on are
# installed in 09-programming-srv6-dataplane.sh.
#
# Two customer organizations, each split across the two PEs:
#
#   org 1  (table 1001):  ce1 (pe1, 10.0.0.0/24)  <->  ce2 (pe2, 10.0.1.0/24)
#   org 2  (table 1002):  ce3 (pe1, 10.0.0.0/24)  <->  ce4 (pe2, 10.0.1.0/24)
#
# This is symmetric, so each direction (ce1->ce2 and ce2->ce1, etc.) is wired up.
# -----------------------------------------------------------------------------

# Same addressing scheme as 02-assign-addresses.sh.
# format: <domain_id>:<region_id(8bits)><node_id(8bits)>
function make_address {
  local domain_id=$1
  local region_id=$2
  local node_id=$3
  local uniq_node_id=$(( (region_id << 8) + node_id ))
  printf "%s:%x" $domain_id $uniq_node_id
}

domain_global="2001:db8:1"

# PE SRv6 locators (the /64 advertised into the underlay, sitting on the srv6 VRF).
pe1_loc=$(make_address $domain_global 1 1)   # 2001:db8:1:101
pe2_loc=$(make_address $domain_global 5 1)   # 2001:db8:1:501

# A SID is a 128-bit IPv6 address: <locator 64bits><function 16bits><arg 48bits>.
# For the PE End.DT4 SIDs defined here:
#   - function code 0 -> End.DT4 (decap inner IPv4, look it up in a VRF table);
#   - the 48-bit argument carries the target customer table id (0x1001 / 0x1002) in
#     its low 16 bits as a mnemonic. The actual table is bound by the End.DT4
#     'vrftable' argument, so the value only needs to be unique.
#   ::1001 == "0:0:0:1001" -> function 0 (End.DT4), arg 0:0:1001 (table 1001)
#   ::1002 == "0:0:0:1002" -> function 0 (End.DT4), arg 0:0:1002 (table 1002)
pe1_sid_1001="${pe1_loc}::1001"   # 2001:db8:1:101::1001
pe1_sid_1002="${pe1_loc}::1002"   # 2001:db8:1:101::1002
pe2_sid_1001="${pe2_loc}::1001"   # 2001:db8:1:501::1001
pe2_sid_1002="${pe2_loc}::1002"   # 2001:db8:1:501::1002

# P-router End SIDs (transit segments), same layout as the End loop in 09:
# <locator 64bits>:<function 1>:<arg 0 0 0>. Only the ones used for steering
# are named here.
p11_end="$(make_address $domain_global 2 1):1::"   # 2001:db8:1:201:1::  (col1,row1)
p31_end="$(make_address $domain_global 2 3):1::"   # 2001:db8:1:203:1::  (col1,row3)
p33_end="$(make_address $domain_global 4 3):1::"   # 2001:db8:1:403:1::  (col3,row3)

# -----------------------------------------------------------------------------
# helpers
# -----------------------------------------------------------------------------

# Install an ingress seg6 encap route in a customer VRF. The $segs argument is a
# comma-separated SID list in TRAVERSAL order: the first SID becomes the outer
# IPv6 DA (visited first), the last SID is the final decap (End.DT4). Transit
# End SIDs are listed in between.
function install_encap_route {
  local node=$1       # ingress PE
  local vrf=$2        # customer VRF (ce1/ce2/ce3/ce4)
  local subnet=$3     # remote customer subnet to reach
  local segs=$4       # comma-separated SID list (transit End SIDs ... decap SID)
  echo "  encap $node  vrf $vrf  $subnet  ->  $segs"
  ip -n "$node" route add "$subnet" vrf "$vrf" encap seg6 mode encap segs "$segs" dev srv6
}

# ---- ingress PE: install the seg6 encap routes in the customer VRFs ---------
#
# org 1 (ce1 <-> ce2): direct PE1 <-> PE2, single segment (decap SID only).
install_encap_route pe1 ce1 10.0.1.0/24 "$pe2_sid_1001"            # ce1 -> ce2 via pe2
install_encap_route pe2 ce2 10.0.0.0/24 "$pe1_sid_1001"            # ce2 -> ce1 via pe1
#
# org 2 (ce3 <-> ce4): steered through the P fabric
#   PE1 -> p11 -> p31 -> p33 -> PE2   (and the reverse for ce4 -> ce3).
install_encap_route pe1 ce3 10.0.1.0/24 "$p11_end,$p31_end,$p33_end,$pe2_sid_1002"   # ce3 -> ce4
install_encap_route pe2 ce4 10.0.0.0/24 "$p33_end,$p31_end,$p11_end,$pe1_sid_1002"   # ce4 -> ce3

# linux SRv6 hack: you must explictly activate the SID table with policy-based routing:
# see: https://segment-routing.org/index.php/Implementation/AdvancedConf
ip -6 -n pe1 rule add to 2001:db8:1::/48 lookup 101
ip -6 -n pe2 rule add to 2001:db8:1::/48 lookup 101

# -----------------------------------------------------------------------------
# verify (run by hand):
#
#   encap routes:     ip -n pe1 route show vrf ce1
#
#   end-to-end (org 1):  ip netns exec ce1 ping 10.0.1.4   # ce1 lo -> ce2 lo
#                        ip netns exec ce2 ping 10.0.0.4   # ce2 lo -> ce1 lo
#   end-to-end (org 2):  ip netns exec ce3 ping 10.0.1.4   # ce3 lo -> ce4 lo
#                        ip netns exec ce4 ping 10.0.0.4   # ce4 lo -> ce3 lo
#
#   trace the SRv6 path: ip netns exec pe1 ip -6 route get <pe2_sid>
# -----------------------------------------------------------------------------
