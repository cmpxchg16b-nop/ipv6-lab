#!/bin/bash

function enable-ospf6 {
  local router_id=$1
  local vrf_specifier=""
  local lo_intf="lo"
  if [ -n "$2" ]; then
    vrf_specifier="vrf $2"
    lo_intf="$2"
  fi

  echo "
enable
conf t
!
router ospf6 $vrf_specifier
  ospf6 router-id $router_id
  log-adjacency-changes
  maximum-paths 1
exit
!
int $lo_intf
  ipv6 ospf6 area 0
  ipv6 ospf6 passive
exit
!
exit
copy run start
exit
"
}

enable-ospf6 1.1.0.0 srv6 | podman exec -it frr-pe1 vtysh
enable-ospf6 5.1.0.0 srv6 | podman exec -it frr-pe2 vtysh

NROWS=3
NCOLS=3
for (( row=1; row<=NROWS; row++ )) do
  for (( col=1; col<=NCOLS; col++ )) do
    region=$((col+1))
    node_num=$row
    enable-ospf6 "$region.$node_num.0.0" | podman exec -it "frr-p${row}${col}" vtysh
  done
done

function en-ospf-if {
  local dst_node=$1
  echo "!
enable
conf t
!
int v-$dst_node
 ipv6 ospf6 area 0
 ipv6 ospf6 network point-to-point
exit
!
exit
copy run start
exit
"
}

function conn-ospf6 {
  local src_node=$1
  local dst_node=$2

  en-ospf-if $dst_node | podman exec -it "frr-${src_node}" vtysh
  en-ospf-if $src_node | podman exec -it "frr-${dst_node}" vtysh
}

for (( row=1; row<=NROWS; row++ )) do
  conn-ospf6 pe1 "p${row}1"
  conn-ospf6 "p${row}3" pe2

  for (( col=1; col<=NCOLS-1; col++ )) do
    src_node="p${row}${col}"
    for (( dstRow=1; dstRow<=NROWS; dstRow++ )) do
      dst_col=$((col+1))
      dst_node="p${dstRow}${dst_col}"
      conn-ospf6 "$src_node" "$dst_node"

      if [ "$dstRow" != "$row" ]; then
        dst_col=$col
        dst_node="p${dstRow}${dst_col}"
        conn-ospf6 "$src_node" "$dst_node"
      fi
    done
  done
done
