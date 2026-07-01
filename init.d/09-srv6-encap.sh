#!/bin/bash

echo Running $0

# -----------------------------------------------------------------------------
# SRv6 L3VPN encapsulation.
#
# Two customer organizations, each split across the two PEs:
#
#   org 1  (table 1001):  ce1 (pe1, 10.0.0.0/24)  <->  ce2 (pe2, 10.0.1.0/24)
#   org 2  (table 1002):  ce3 (pe1, 10.0.0.0/24)  <->  ce4 (pe2, 10.0.1.0/24)
#
# At the INGRESS PE the customer packet (arriving in its VRF) is wrapped in an
# outer IPv6/SRH (mode encap) whose destination is the EGRESS PE's SID, then
# handed to the 'srv6' VRF (table 101) to be carried over the OSPFv3 underlay.
#
# At the EGRESS PE the SID triggers End.DT4: the inner IPv4 packet is decapsulated
# and looked up in the matching customer VRF table (1001 / 1002), reaching the CE.
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

# A SID = <locator>::<function>. We use the function hextet as a mnemonic for the
# customer table the egress PE must decap-and-lookup into. The actual table is set
# by the End.DT4 'vrftable' argument; the hextet only needs to be unique.
#   ::1001  ->  vrftable 1001  (org 1)
#   ::1002  ->  vrftable 1002  (org 2)
pe1_sid_1001="${pe1_loc}::1001"   # 2001:db8:1:101::1001
pe1_sid_1002="${pe1_loc}::1002"   # 2001:db8:1:101::1002
pe2_sid_1001="${pe2_loc}::1001"   # 2001:db8:1:501::1001
pe2_sid_1002="${pe2_loc}::1002"   # 2001:db8:1:501::1002

# -----------------------------------------------------------------------------
# helpers
# -----------------------------------------------------------------------------

# Install an End.DT4 localsid on a PE: decap inner IPv4 and lookup in a VRF table.
function install_decap_sid {
  local node=$1       # pe1 / pe2
  local sid=$2        # full SID (function hextet identifies the table)
  local table_id=$3   # customer VRF table to decap into (1001 / 1002)
  local ce_vrf=$4     # customer VRF name
  echo "  decap $node  sid ${sid}/128  ->  table $table_id"
  ip -n "$node" route add "${sid}/128" vrf srv6 encap seg6local action End.DT4 vrftable $table_id dev $ce_vrf
}

# Install an ingress seg6 encap route in a customer VRF toward an egress PE SID.
function install_encap_route {
  local node=$1       # ingress PE
  local vrf=$2        # customer VRF (ce1/ce2/ce3/ce4)
  local subnet=$3     # remote customer subnet to reach
  local sid=$4        # egress PE's SID
  echo "  encap $node  vrf $vrf  $subnet  ->  $sid"
  ip -n "$node" route add "$subnet" vrf "$vrf" encap seg6 mode encap segs "$sid" dev srv6
}

# ---- egress PE: install the End.DT4 decap SIDs (localsid table) -------------
# End.DT4: decapsulate the inner IPv4 packet and look it up in 'vrftable'.
#
# pe1 serves traffic coming -from- pe2 (towards ce1/ce3):
install_decap_sid pe1 "$pe1_sid_1001" 1001 ce1   # -> table 1001 (ce1)
install_decap_sid pe1 "$pe1_sid_1002" 1002 ce3   # -> table 1002 (ce3)
# pe2 serves traffic coming -from- pe1 (towards ce2/ce4):
install_decap_sid pe2 "$pe2_sid_1001" 1001 ce2  # -> table 1001 (ce2)
install_decap_sid pe2 "$pe2_sid_1002" 1002 ce4  # -> table 1002 (ce4)

# ---- ingress PE: install the seg6 encap routes in the customer VRFs ---------
# mode encap wraps the inner IPv4 packet in an outer IPv6/SRH destined to the
# egress PE's SID, then emits the outer packet via the srv6 VRF (table 101) for
# transport across the underlay.
#
# org 1 (ce1 <-> ce2):
install_encap_route pe1 ce1 10.0.1.0/24 "$pe2_sid_1001"   # ce1 -> ce2 via pe2
install_encap_route pe2 ce2 10.0.0.0/24 "$pe1_sid_1001"   # ce2 -> ce1 via pe1
#
# org 2 (ce3 <-> ce4):
install_encap_route pe1 ce3 10.0.1.0/24 "$pe2_sid_1002"   # ce3 -> ce4 via pe2
install_encap_route pe2 ce4 10.0.0.0/24 "$pe1_sid_1002"   # ce4 -> ce3 via pe1

# linux SRv6 hack: you must explictly activate the SID table with policy-based routing:
# see: https://segment-routing.org/index.php/Implementation/AdvancedConf
ip -6 -n pe1 rule add to 2001:db8:1::/48 lookup 101
ip -6 -n pe2 rule add to 2001:db8:1::/48 lookup 101

# -----------------------------------------------------------------------------
# verify (run by hand):
#
#   localsids:        ip -n pe1 -6 route show table local | grep -i seg6local
#   encap routes:     ip -n pe1 route show vrf ce1
#
#   end-to-end (org 1):  ip netns exec ce1 ping 10.0.1.4   # ce1 lo -> ce2 lo
#                        ip netns exec ce2 ping 10.0.0.4   # ce2 lo -> ce1 lo
#   end-to-end (org 2):  ip netns exec ce3 ping 10.0.1.4   # ce3 lo -> ce4 lo
#                        ip netns exec ce4 ping 10.0.0.4   # ce4 lo -> ce3 lo
#
#   trace the SRv6 path: ip netns exec pe1 ip -6 route get <pe2_sid>
# -----------------------------------------------------------------------------
