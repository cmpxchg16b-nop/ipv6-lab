#!/bin/bash

# CE5 (connects to PE1) and CE6 (connects to PE2) are belong to the same org,
# and they use BGP to connects to us.
# Let's say they are AS65001, we are AS65002.

#!/bin/bash

# PE1 is the upstream of CE1, CE1 is a customer
function config-pe1 {
  echo "
enable
configure terminal
ip prefix-list allow-in seq 5 permit 10.0.0.0/24 ge 24 le 24
ip prefix-list allow-in seq 10 permit 10.0.1.0/24 ge 24 le 24
ip prefix-list allow-out seq 5 permit 0.0.0.0/0 ge 0 le 32
!
router bgp 65002 vrf ce5
 bgp router-id 169.254.1.102
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 no bgp network import-check
 neighbor 10.0.0.1 remote-as 65001
 neighbor 10.0.0.1 update-source 10.0.0.2
 !
 address-family ipv4 unicast
  neighbor 10.0.0.1 activate
  neighbor 10.0.0.1 as-override
  neighbor 10.0.0.1 prefix-list allow-in in
  neighbor 10.0.0.1 prefix-list allow-out out
  sid vpn export auto
  rd vpn export 65001:1003
  rt vpn both 65001:1003
  export vpn
  import vpn
 exit-address-family
exit
!
router bgp 65002
 bgp router-id 1.1.0.0
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 no bgp network import-check
 neighbor 2001:db8:2:501:: remote-as 65002
 neighbor 2001:db8:2:501:: update-source 2001:db8:2:101::
 neighbor 2001:db8:2:501:: capability extended-nexthop
 !
 segment-routing srv6
  locator main
 exit
 !
 address-family ipv4 vpn
  neighbor 2001:db8:2:501:: activate
 exit-address-family
exit
!
segment-routing
 srv6
  locators
   locator main
    prefix 2001:db8:2:101::/64 block-len 48 node-len 16
   exit
   !
  exit
  !
 exit
 !
exit
!
exit
!
exit
"
}

# PE2 is the upstream of CE2, CE2 is a customer
function config-pe2 {
  echo "
enable
configure terminal
ip prefix-list allow-in seq 5 permit 10.0.0.0/24 ge 24 le 24
ip prefix-list allow-in seq 10 permit 10.0.1.0/24 ge 24 le 24
ip prefix-list allow-out seq 5 permit 0.0.0.0/0 ge 0 le 32
!
router bgp 65002 vrf ce6
 bgp router-id 169.254.2.102
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 no bgp network import-check
 neighbor 10.0.1.1 remote-as 65001
 neighbor 10.0.1.1 update-source 10.0.1.2
 !
 address-family ipv4 unicast
  neighbor 10.0.1.1 activate
  neighbor 10.0.1.1 prefix-list allow-in in
  neighbor 10.0.1.1 prefix-list allow-out out
  neighbor 10.0.0.1 as-override
  sid vpn export auto
  rd vpn export 65001:1003
  rt vpn both 65001:1003
  export vpn
  import vpn
 exit-address-family
exit
!
router bgp 65002
 bgp router-id 5.5.0.0
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 no bgp network import-check
 neighbor 2001:db8:2:101:: remote-as 65002
 neighbor 2001:db8:2:101:: update-source 2001:db8:2:501::
 neighbor 2001:db8:2:101:: capability extended-nexthop
 !
 segment-routing srv6
  locator main
 exit
 !
 address-family ipv4 vpn
  neighbor 2001:db8:2:101:: activate
 exit-address-family
exit
!
segment-routing
 srv6
  locators
   locator main
    prefix 2001:db8:2:501::/64 block-len 48 node-len 16
   exit
   !
  exit
  !
 exit
 !
exit
!
exit
!
exit
"
}

function config-ce5 {
  echo "
enable
configure terminal
ip prefix-list allow-all seq 5 permit 0.0.0.0/0 ge 0 le 32
ip prefix-list allow-self seq 5 permit 10.0.0.0/24 ge 24 le 24
!
router bgp 65001
 bgp router-id 169.254.1.101
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 neighbor 10.0.0.2 remote-as 65002
 neighbor 10.0.0.2 update-source 10.0.0.1
 !
 address-family ipv4 unicast
  network 10.0.0.0/24
  neighbor 10.0.0.2 activate
  neighbor 10.0.0.2 prefix-list allow-all in
  neighbor 10.0.0.2 prefix-list allow-self out
 exit-address-family
exit
!
exit
!
exit
"
}

function config-ce6 {
  echo "
enable
configure terminal
ip prefix-list allow-all seq 5 permit 0.0.0.0/0 ge 0 le 32
ip prefix-list allow-self seq 5 permit 10.0.1.0/24 ge 24 le 24
!
router bgp 65001
 bgp router-id 169.254.2.101
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 neighbor 10.0.1.2 remote-as 65002
 neighbor 10.0.1.2 update-source 10.0.1.1
 !
 address-family ipv4 unicast
  network 10.0.1.0/24
  neighbor 10.0.1.2 activate
  neighbor 10.0.1.2 prefix-list allow-all in
  neighbor 10.0.1.2 prefix-list allow-self out
 exit-address-family
exit
!
exit
!
exit
"
}


config-pe1 | podman exec -it frr-pe1 vtysh
config-pe2 | podman exec -it frr-pe2 vtysh
config-ce5 | podman exec -it frr-ce5 vtysh
config-ce6 | podman exec -it frr-ce6 vtysh
