#!/bin/bash

echo Running $0

dirname=$(dirname $0)
cd "$dirname/.."

for ns in pe1 p11 p12 p13 p21 p22 p23 p31 p32 p33 pe2 ce5 ce6; do
  echo create $ns
  mkdir -p nodes/$ns/frr.conf.d
  cp -r frr.conf.d/. nodes/$ns/frr.conf.d
  echo '' > nodes/$ns/frr.conf.d/frr.conf

  echo hostname $ns >> nodes/$ns/frr.conf.d/frr.conf
  echo log stdout informational >> nodes/$ns/frr.conf.d/frr.conf
done
