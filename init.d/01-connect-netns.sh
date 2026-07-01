#!/bin/bash

echo Running $0

function conn {
  ip l add v-$2 netns $1 type veth peer v-$1 netns $2
  ip -n $1 l set v-$2 up
  ip -n $2 l set v-$1 up
}

function conn_from_vrf {
  local vrf=$1
  local src="$2"
  local dst="$3"

  local lhs_if="v-$dst"
  local rhs_if="v-$src"


  ip l add "$lhs_if" netns "$src" type veth peer "$rhs_if" netns "$dst"
  ip -n "$src" l set "$lhs_if" vrf "$vrf"
  ip -n "$src" l set "$lhs_if" up
  ip -n "$dst" l set "$rhs_if" up
}

function conn_to_vrf {
  local src="$1"
  local dst="$2"
  local vrf=$3

  local lhs_if="v-$dst"
  local rhs_if="v-$src"

  ip l add "$lhs_if" netns "$src" type veth peer "$rhs_if" netns "$dst"
  ip -n "$src" l set "$lhs_if" up
  ip -n "$dst" l set "$rhs_if" vrf "$vrf"
  ip -n "$dst" l set "$rhs_if" up
}

NROWS=3
NCOLS=3
for (( col=1; col<=NCOLS-1; col++ )) do
  for (( row=1; row<=NROWS; row++ )) do
    srcNode="p${row}${col}"
    for (( dstRow=1; dstRow<=NROWS; dstRow++ )) do
      dstNode="p${dstRow}$((col+1))"
      echo connect $srcNode $dstNode
      conn $srcNode $dstNode
    done
  done
done

for (( row=1; row<=NROWS; row++ )) do
  srcNode="pe1"
  dstNode="p${row}1"
  echo connect $srcNode $dstNode
  conn_from_vrf srv6 $srcNode $dstNode

  srcNode="p${row}3"
  dstNode="pe2"
  echo "connect $srcNode $dstNode"
  conn_to_vrf $srcNode $dstNode srv6
done
