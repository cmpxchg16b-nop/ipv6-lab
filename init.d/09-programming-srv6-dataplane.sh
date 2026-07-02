#!/bin/bash

echo Running $0

# -----------------------------------------------------------------------------
# SRv6 L3VPN: program the data plane (local SID tables).
#
# This script installs the SRv6 local SIDs on every node:
#
#   * EGRESS PE  -> End.DT4  (decap inner IPv4, lookup in customer VRF table)
#   * transit P  -> End      (pop SRH active segment, forward toward next SID)
#
# The matching ingress side (seg6 encap / steering routes installed in the
# customer VRFs) is set up in 10-setup-pe-srv6-routes.sh.
#
# Two customer organizations, each split across the two PEs:
#
#   org 1  (table 1001):  ce1 (pe1, 10.0.0.0/24)  <->  ce2 (pe2, 10.0.1.0/24)
#   org 2  (table 1002):  ce3 (pe1, 10.0.0.0/24)  <->  ce4 (pe2, 10.0.1.0/24)
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

# -----------------------------------------------------------------------------
# helpers
# -----------------------------------------------------------------------------

# Install an End.DT4 localsid on a PE: decap inner IPv4 and lookup in a VRF table.
function install_decap_sid {
  local node=$1       # pe1 / pe2
  local sid=$2        # full SID (function hextet identifies the table)
  local table_id=$3   # customer VRF table to decap into (1001 / 1002)
  local ce_vrf=$4     # customer VRF name
  local action=$5
  echo "  decap $node  sid ${sid}/128  ->  table $table_id"
  ip -n "$node" route add "${sid}/128" encap seg6local action $action vrftable $table_id dev $ce_vrf
}

# Install an End localsid on a transit P-router: the basic SRv6 endpoint that
# advances the SRH to the next segment and forwards toward it.
function install_end_sid {
  local node=$1       # p11 / p12 / ... / p33
  local sid=$2        # full SID  (<locator>:1:0  -> function 1, arg 0)
  echo "  end   $node  sid ${sid}/128"
  ip -n "$node" route add "${sid}/128" encap seg6local action End dev lo
  ip -n "$node" address add "${sid}/128" dev lo
}

install_decap_sid pe1 "$pe1_sid_1001" 1001 ce1 End.DT4
install_decap_sid pe1 "$pe1_sid_1002" 1002 ce3 End.DT4
install_decap_sid pe2 "$pe2_sid_1001" 1001 ce2 End.DT4
install_decap_sid pe2 "$pe2_sid_1002" 1002 ce4 End.DT4

install_decap_sid pe1 "$pe1_sid_dt6_1001" 1001 ce1 End.DT6
install_decap_sid pe1 "$pe1_sid_dt6_1002" 1002 ce3 End.DT6
install_decap_sid pe2 "$pe2_sid_dt6_1001" 1001 ce2 End.DT6
install_decap_sid pe2 "$pe2_sid_dt6_1002" 1002 ce4 End.DT6

# ---- transit P-routers: install End localsids ------------------------------
# The End behavior is the basic SRv6 transit endpoint: it pops the SRH's active
# segment and forwards to the next. Every P-router gets one so traffic-engineered
# paths can steer through it.
#
# SID = <locator 64bits>:<function 16bits>:<arg 48bits>
#   function code 0  -> End.DT4  (already taken by the PEs)
#   function code 1  -> End      (transit P-routers)
#   arg 0 (the whole 48-bit field) -> unused for End.
NROWS=3
NCOLS=3
for (( col=1; col<=NCOLS; col++ )); do
  for (( row=1; row<=NROWS; row++ )); do
    node="p${row}${col}"
    region=$((col+1))                       # column 1->region 2, 2->3, 3->4
    p_loc=$(make_address $domain_global $region $row)
    p_end_sid="${p_loc}:${func_code_1_end}::"                 # <locator>:<func 1>:<arg 0 0 0>
    install_end_sid "$node" "$p_end_sid"
  done
done

# -----------------------------------------------------------------------------
# verify (run by hand):
#
#   localsids (PE):   ip -n pe1 -6 route show table local | grep -i seg6local
#   localsids (P):    ip -n p11 -6 route show table local | grep -i seg6local
#
#   end-to-end and steering checks live in 10-setup-pe-srv6-routes.sh.
# -----------------------------------------------------------------------------
