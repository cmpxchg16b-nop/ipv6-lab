#!/bin/bash

function conn {
  ip l add v-$2 netns $1 type veth peer v-$1 netns $2
  ip -n $1 l set v-$2 up
  ip -n $2 l set v-$1 up
}

NROWS=3
NCOLS=3
for (( col=1; col<=NCOLS-1; col++ )) do
  for (( row=1; row<=NROWS; row++ )) do
    srcNode="p${row}${col}"
    for (( dstRow=1; dstRow<=NROWS; dstRow++ )) do
      dstNode="p${dstRow}$((col+1))"
      echo connecting $srcNode $dstNode
      conn $srcNode $dstNode
    done
  done
done

for (( row=1; row<=NROWS; row++ )) do
  srcNode="pe1"
  dstNode="p${row}1"
  echo connecting $srcNode $dstNode
  conn $srcNode $dstNode

  srcNode="p${row}3"
  dstNode="pe2"
  echo "connecting $srcNode $dstNode"
  conn $srcNode $dstNode
done
