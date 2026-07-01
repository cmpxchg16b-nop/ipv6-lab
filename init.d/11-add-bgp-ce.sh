#!/bin/bash

# CE5 (connects to PE1) and CE6 (connects to PE2) are belong to the same org,
# and they use BGP to connects to us.
# Let's say they are AS65001, we are AS65002.

#!/bin/bash

function enable-bgp {
  local asn=$1
  local router_id=$2
  local vrf_specifier=""
  if [ -n "$3" ]; then
    vrf_specifier="vrf $3"
  fi

  echo "
enable
conf t
!
router bgp $asn $vrf_specifier
  bgp router-id $router_id
  no bgp default ipv4-unicast
exit
!
exit
copy run start
exit
"
}

enable-bgp 65001 169.254.1.101 | podman exec -it frr-ce5 vtysh
enable-bgp 65002 169.254.1.102 ce5 | podman exec -it frr-pe1 vtysh

enable-bgp 65001 169.254.2.101 | podman exec -it frr-ce6 vtysh
enable-bgp 65002 169.254.2.102 ce6 | podman exec -it frr-pe2 vtysh

function bgp-add-neighbor {
  local asn=$1
  local neighbor_asn=$2
  local neighbor_ip=$3

  local vrf_specifier=""
  if [ -n "$4" ]; then
    vrf_specifier="vrf $4"
  fi

  echo "
enable
conf t
!
router bgp $asn $vrf_specifier
  neighbor $neighbor_ip remote-as $neighbor_asn
exit
!
exit
copy run start
exit
"
}

bgp-add-neighbor 65001 65002 10.0.0.2 | podman exec -it frr-ce5 vtysh
bgp-add-neighbor 65002 65001 10.0.0.1 ce5 | podman exec -it frr-pe1 vtysh

bgp-add-neighbor 65001 65002 10.0.1.2 | podman exec -it frr-ce6 vtysh
bgp-add-neighbor 65002 65001 10.0.1.1 ce6 | podman exec -it frr-pe2 vtysh

function bgp-advertise-network-to-neighbor {
  local bgp_selector=$1
  local neighbor=$2
  local network=$3

  echo "
enable
conf t
!
ip prefix-list allow-all seq 5 permit 0.0.0.0/0 ge 0 le 32
ip prefix-list allow-self seq 5 permit $network ge 24 le 24
!
router bgp $bgp_selector
  address-family ipv4 unicast
    network $network
    neighbor $neighbor activate
    neighbor $neighbor prefix-list allow-all in
    neighbor $neighbor prefix-list allow-self out
  exit-address-family
exit
!
exit
copy run start
exit
"
}

bgp-advertise-network-to-neighbor 65001 10.0.0.2 10.0.0.0/24 | podman exec -it frr-ce5 vtysh
bgp-advertise-network-to-neighbor 65001 10.0.1.2 10.0.1.0/24 | podman exec -it frr-ce6 vtysh

function bgp-set-pe-allow-list {
  local bgp_selector=$1
  local vrf=$2
  local neighbor=$3

  echo "
enable
conf t
!
ip prefix-list allow-in seq 5 permit 10.0.0.0/24 ge 24 le 24
ip prefix-list allow-in seq 10 permit 10.0.1.0/24 ge 24 le 24
ip prefix-list allow-out seq 5 permit 0.0.0.0/0 ge 0 le 32
!
router bgp $bgp_selector vrf $vrf
  address-family ipv4 unicast
    neighbor $neighbor prefix-list allow-in in
    neighbor $neighbor prefix-list allow-out out
  exit-address-family
exit
!
exit
copy run start
exit
"
}

bgp-set-pe-allow-list 65002 ce5 10.0.0.1 | podman exec -it frr-pe1 vtysh
bgp-set-pe-allow-list 65002 ce6 10.0.1.1 | podman exec -it frr-pe2 vtysh
