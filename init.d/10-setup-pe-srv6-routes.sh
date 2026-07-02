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

func_code_0_end_dt4=""
func_code_1_end="1"
func_code_2_end_dt6="2"

# PE SRv6 locators (the /64 advertised into the underlay, sitting on the default VRF).
pe1_loc=$(make_address $domain_global 1 1)   # 2001:db8:1:101
pe2_loc=$(make_address $domain_global 5 1)   # 2001:db8:1:501

# A SID is a 128-bit IPv6 address: <locator 64bits><function 16bits><arg 48bits>.
pe1_sid_1001="${pe1_loc}:${func_code_0_end_dt4}:1001"
pe1_sid_1002="${pe1_loc}:${func_code_0_end_dt4}:1002"
pe2_sid_1001="${pe2_loc}:${func_code_0_end_dt4}:1001"
pe2_sid_1002="${pe2_loc}:${func_code_0_end_dt4}:1002"

pe1_sid_dt6_1001="${pe1_loc}:${func_code_2_end_dt6}::1001"
pe1_sid_dt6_1002="${pe1_loc}:${func_code_2_end_dt6}::1002"
pe2_sid_dt6_1001="${pe2_loc}:${func_code_2_end_dt6}::1001"
pe2_sid_dt6_1002="${pe2_loc}:${func_code_2_end_dt6}::1002"

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
  local nh=$5
  echo "  encap $node  vrf $vrf  $subnet  ->  $segs"
  ip -n "$node" route add "$subnet" vrf "$vrf" encap seg6 mode encap segs "$segs" dev $nh
}

install_encap_route pe1 ce1 10.0.1.0/24 "$pe2_sid_1001" lo
install_encap_route pe2 ce2 10.0.0.0/24 "$pe1_sid_1001" lo
install_encap_route pe1 ce1 fd00:1:1::/48 "$pe2_sid_dt6_1001" v-p21
install_encap_route pe2 ce2 fd00:1::/48 "$pe1_sid_dt6_1001" v-p23
install_encap_route pe1 ce3 10.0.1.0/24 "$p11_end,$p31_end,$p33_end,$pe2_sid_1002" lo
install_encap_route pe2 ce4 10.0.0.0/24 "$p33_end,$p31_end,$p11_end,$pe1_sid_1002" lo
install_encap_route pe1 ce3 fd00:1:1::/48 "$p11_end,$p31_end,$p33_end,$pe2_sid_dt6_1002" v-p11
install_encap_route pe2 ce4 fd00:1::/48 "$p33_end,$p31_end,$p11_end,$pe1_sid_dt6_1002" v-p33

# routes:
#
# 10.0.1.0/24,fd00:1:1::/48 -> CE2 (via PE2, "$pe2_sid_1001", "$pe2_sid_dt6_1001")
# 10.0.0.0/24,fd00:1::/48 -> CE1 (via PE1, "$pe1_sid_1001", "$pe1_sid_dt6_1001")
#
# 10.0.1.0/24,fd00:1:1::/48 -> CE4 (via PE2, "$pe2_sid_1002", "$pe2_sid_dt6_1002")
# 10.0.0.0/24,fd00:1::/48 -> CE3 (via PE1, "$pe1_sid_1002", "$pe1_sid_dt6_1002")
#
# CE5, CE6 use dynamic routing.
