#!/bin/bash

for ns in pe1 p11 p12 p13 p21 p22 p23 p31 p32 p33 pe2 ce5 ce6; do
  echo delete $ns
  rm -r nodes/$ns
done

rm -r nodes
