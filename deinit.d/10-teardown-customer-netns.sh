#!/bin/bash

for ns in ce1 ce2 ce3 ce4; do
  echo delete $ns
  ip netns del $ns
done
