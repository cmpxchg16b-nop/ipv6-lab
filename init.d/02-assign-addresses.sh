#!/bin/bash

echo Running $0

# format: <domain_id>:<region_id(8bits)><node_id(8bits)>
function make_address {
  local domain_id=$1
  local region_id=$2
  local node_id=$3
  local uniq_node_id=$(( (region_id << 8) + node_id ))
  printf "%s:%x" $domain_id $uniq_node_id
}

# order id can only be 0 or 1
# format: <domain_id>:<src_region(8bits)><src_node(8bits)>::<dst_region(8bits)><dst_node(8bits)>:<order(1bit)>
function make_ptp_address {
  local domain_id=$1
  local src_region_id=$2
  local src_node_id=$3
  local dst_region_id=$4
  local dst_node_id=$5
  local order_id=$6

  local src_uniq_node_id=$(( (src_region_id << 8) + src_node_id ))
  local dst_uniq_node_id=$(( (dst_region_id << 8) + dst_node_id ))

  printf "%s:%x::%x:%x" $domain_id $src_uniq_node_id $dst_uniq_node_id $order_id
}

domain_global="2001:db8:1"

declare -A region_ids
last_region_id=1
echo node pe1 region $last_region_id
region_ids["pe1"]=$last_region_id
last_region_id=$((last_region_id+1))

NROWS=3
NCOLS=3
for (( col=1; col<=NCOLS; col++ )) do
  for (( row=1; row<=NROWS; row++ )) do
    node="p${row}${col}"
    echo node $node region $last_region_id
    region_ids[$node]=$last_region_id
  done
  last_region_id=$((last_region_id+1))
done

echo node pe2 region $last_region_id
region_ids["pe2"]=$last_region_id

declare -A node_addresses
region=${region_ids["pe1"]}
node_addresses["pe1"]=$(make_address $domain_global $region 1)
echo node pe1 address ${node_addresses["pe1"]}

region=${region_ids["pe2"]}
node_addresses["pe2"]=$(make_address $domain_global $region 1)
echo node pe2 address ${node_addresses["pe2"]}

for (( col=1; col<=NCOLS; col++ )) do
  for (( row=1; row<=NROWS; row++ )) do
    node="p${row}${col}"
    region=${region_ids[$node]}
    add=$(make_address $domain_global $region $row)
    node_addresses[$node]=$add
    echo node $node address $add
  done
done


for (( row=1; row<=NROWS; row++ )) do
  src_node=pe1
  src_node_num=1
  src_region=${region_ids[$src_node]}

  dst_node="p${row}1"
  dst_region=${region_ids[$dst_node]}
  dst_node_num="${row}"

  lhs_addr="$(make_ptp_address $domain_global $src_region $src_node_num $dst_region $dst_node_num 0)/127"
  rhs_addr="$(make_ptp_address $domain_global $src_region $src_node_num $dst_region $dst_node_num 1)/127"
  echo ptp address of $src_node "<->" "${dst_node}:" $lhs_addr "<->" $rhs_addr
  ip -n $src_node address add $lhs_addr dev "v-$dst_node"
  ip -n $dst_node address add $rhs_addr dev "v-$src_node"

  src_node="p${row}3"
  src_node_num="${row}"
  src_region=${region_ids[$src_node]}

  dst_node="pe2"
  dst_node_num=1
  dst_region=${region_ids[$dst_node]}

  lhs_addr="$(make_ptp_address $domain_global $src_region $src_node_num $dst_region $dst_node_num 0)/127"
  rhs_addr="$(make_ptp_address $domain_global $src_region $src_node_num $dst_region $dst_node_num 1)/127"
  echo ptp address of $src_node "<->" "${dst_node}:" $lhs_addr "<->" $rhs_addr
  ip -n $src_node address add $lhs_addr dev "v-$dst_node"
  ip -n $dst_node address add $rhs_addr dev "v-$src_node"

  for (( col=1; col<=NCOLS-1; col++ )) do
    src_node="p${row}${col}"
    src_region=${region_ids[$src_node]}
    src_num="${row}"

    for (( dstRow=1; dstRow<=NROWS; dstRow++ )) do
      dst_col=$((col+1))
      dst_node="p${dstRow}${dst_col}"
      dst_region=${region_ids[$dst_node]}
      dst_num="${dstRow}"

      lhs_addr="$(make_ptp_address $domain_global $src_region $src_num $dst_region $dst_num 0)/127"
      rhs_addr="$(make_ptp_address $domain_global $src_region $src_num $dst_region $dst_num 1)/127"

      echo ptp address of $src_node "<->" "${dst_node}:" $lhs_addr "<->" $rhs_addr
      ip -n $src_node address add $lhs_addr dev "v-$dst_node"
      ip -n $dst_node address add $rhs_addr dev "v-$src_node"
    done
  done
done

for node in "${!node_addresses[@]}"; do
  addr=${node_addresses[$node]}
  echo "assign" "${addr}::/64" to $node
  ip -n $node address add $addr::/64 dev lo
done
