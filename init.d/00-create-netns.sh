#!/bin/bash

for ns in pe1 p11 p12 p13 p21 p22 p23 p31 p32 p33 pe2; do
  echo ns $ns
  ip netns add $ns
  ip -n $ns l set lo up
done
