#!/bin/bash

echo Running $0

# -----------------------------------------------------------------------------
# SRv6 traffic steering for BOTH customer orgs.
#
# 09-srv6-encap.sh wires each customer VRF to a single-segment encap straight to
# the remote PE's End.DT4 SID. This script forces CE traffic through explicit
# transit P-routers by inserting intermediate End segments ahead of that final
# decap SID. Both directions (PE1->PE2 and PE2->PE1) are steered along mirrored
# paths, so each org's traffic traverses the same routers in both ways.
#
# Within-column links (p<r,c> <-> p<r',c>) are enabled in 05-config-frr.sh, so
# the paths below are real physical paths across the fabric, not just SRv6 hops.
#
#   org 1 (table 1001, ce1 <-> ce2):
#     CE1  PE1 -> P21 -> P22 -> P23 -> PE2  CE2
#     CE2  PE2 -> P23 -> P22 -> P21 -> PE1  CE1
#
#   org 2 (table 1002, ce3 <-> ce4):
#     CE3  PE1 -> P11 -> P21 -> P31 -> P32 -> P33 -> P23 -> PE2  CE4
#     CE4  PE2 -> P23 -> P33 -> P32 -> P31 -> P21 -> P11 -> PE1  CE3
#
# A SID = <locator>::<function>.
#   ::1001 / ::1002  -> End.DT4 decap into table 1001 / 1002   (installed in 09)
#   ::1              -> End (transit) on a P-router             (installed here)
# The End function uses a fresh code (::1), distinct from End.DT4 (::1001/::1002)
# and from 0.
# -----------------------------------------------------------------------------

# Same addressing scheme as 02-assign-addresses.sh / 09-srv6-encap.sh.
# format: <domain_id>:<region_id(8bits)><node_id(8bits)>
function make_address {
  local domain_id=$1
  local region_id=$2
  local node_id=$3
  local uniq_node_id=$(( (region_id << 8) + node_id ))
  printf "%s:%x" $domain_id $uniq_node_id
}

domain_global="2001:db8:1"

# Region map (matches 02-assign-addresses.sh):
#   pe1 -> 1 ; col1 (p*1) -> 2 ; col2 (p*2) -> 3 ; col3 (p*3) -> 4 ; pe2 -> 5
# Node id within a column = row number.

# PE locators and their org End.DT4 SIDs (final decap, installed by 09).
pe1_loc=$(make_address $domain_global 1 1)   # 2001:db8:1:101
pe2_loc=$(make_address $domain_global 5 1)   # 2001:db8:1:501
pe1_sid_1001="${pe1_loc}::1001"              # 2001:db8:1:101::1001
pe1_sid_1002="${pe1_loc}::1002"              # 2001:db8:1:101::1002
pe2_sid_1001="${pe2_loc}::1001"              # 2001:db8:1:501::1001
pe2_sid_1002="${pe2_loc}::1002"              # 2001:db8:1:501::1002

# End function hextet: fresh code, distinct from End.DT4 (::1001/::1002) and 0.
end_func=1

# P-router locator: <domain>:<region><node>, region = col+1, node = row.
function p_loc {
  local row=$1 col=$2
  make_address $domain_global $((col+1)) "$row"
}

# End SIDs for every transit router used by the paths below.
p11_sid="$(p_loc 1 1)::${end_func}"   # 2001:db8:1:201::1
p21_sid="$(p_loc 2 1)::${end_func}"   # 2001:db8:1:202::1
p31_sid="$(p_loc 3 1)::${end_func}"   # 2001:db8:1:203::1
p22_sid="$(p_loc 2 2)::${end_func}"   # 2001:db8:1:302::1
p32_sid="$(p_loc 3 2)::${end_func}"   # 2001:db8:1:303::1
p23_sid="$(p_loc 2 3)::${end_func}"   # 2001:db8:1:402::1
p33_sid="$(p_loc 3 3)::${end_func}"   # 2001:db8:1:403::1

# -----------------------------------------------------------------------------
# helpers
# -----------------------------------------------------------------------------

# Install an End (transit) localsid on a P-router: advance the SRH, write the next
# segment into the outer DA and forward. P-routers carry no srv6 VRF, so the
# locator is on lo and the localsid lives in the default local table.
function install_end_sid {
  local node=$1 sid=$2
  echo "  end   $node  sid ${sid}/128"
  ip -n "$node" route add "${sid}/128" encap seg6local action End dev lo
}

# Replace a customer-VRF encap route (from 09) with one whose SRH visits the given
# transit SIDs in order before the final egress decap SID. SIDs are listed in
# visit order; the first becomes the outer destination address.
function steer_encap_route {
  local node=$1 vrf=$2 subnet=$3
  shift 3
  local segs
  local IFS=,
  segs="$*"
  echo "  steer $node  vrf $vrf  $subnet  ->  [$segs]"
  ip -n "$node" route del "$subnet" vrf "$vrf" 2>/dev/null
  ip -n "$node" route add "$subnet" vrf "$vrf" encap seg6 mode encap segs "$segs" dev srv6
}

# ---- transit P-routers: install the End SIDs --------------------------------
install_end_sid p11 "$p11_sid"
install_end_sid p21 "$p21_sid"
install_end_sid p31 "$p31_sid"
install_end_sid p22 "$p22_sid"
install_end_sid p32 "$p32_sid"
install_end_sid p23 "$p23_sid"
install_end_sid p33 "$p33_sid"

# ---- org 1 (ce1 <-> ce2): P21 -> P22 -> P23 ---------------------------------
# forward:  CE1 @ PE1 -> P21 -> P22 -> P23 -> PE2 (End.DT4 ::1001)
steer_encap_route pe1 ce1 10.0.1.0/24 "$p21_sid" "$p22_sid" "$p23_sid" "$pe2_sid_1001"
# reverse:  CE2 @ PE2 -> P23 -> P22 -> P21 -> PE1 (End.DT4 ::1001)
steer_encap_route pe2 ce2 10.0.0.0/24 "$p23_sid" "$p22_sid" "$p21_sid" "$pe1_sid_1001"

# ---- org 2 (ce3 <-> ce4): P11 -> P21 -> P31 -> P32 -> P33 -> P23 -------------
# forward:  CE3 @ PE1 -> P11 -> P21 -> P31 -> P32 -> P33 -> P23 -> PE2 (End.DT4 ::1002)
steer_encap_route pe1 ce3 10.0.1.0/24 "$p11_sid" "$p21_sid" "$p31_sid" "$p32_sid" "$p33_sid" "$p23_sid" "$pe2_sid_1002"
# reverse:  CE4 @ PE2 -> P23 -> P33 -> P32 -> P31 -> P21 -> P11 -> PE1 (End.DT4 ::1002)
steer_encap_route pe2 ce4 10.0.0.0/24 "$p23_sid" "$p33_sid" "$p32_sid" "$p31_sid" "$p21_sid" "$p11_sid" "$pe1_sid_1002"

# -----------------------------------------------------------------------------
# verify (run by hand):
#
#   End localsids:  ip -n p11 -6 route show table local | grep -i seg6local
#                   (repeat for p21, p31, p22, p32, p23, p33)
#
#   steered encap:  ip -n pe1 route show vrf ce1     # org 1 forward SRH
#                   ip -n pe2 route show vrf ce2     # org 1 reverse SRH
#                   ip -n pe1 route show vrf ce3     # org 2 forward SRH
#                   ip -n pe2 route show vrf ce4     # org 2 reverse SRH
#
#   end-to-end:     ip netns exec ce1 ping 10.0.1.4   # ce1 -> p21 -> p22 -> p23 -> pe2 -> ce2
#                   ip netns exec ce3 ping 10.0.1.4   # ce3 -> p11 -> p21 -> p31 -> p32 -> p33 -> p23 -> pe2 -> ce4
#
#   trace SRv6:     ip netns exec pe1 ip -6 route get $p21_sid   # first hop of org 1/2
# -----------------------------------------------------------------------------
