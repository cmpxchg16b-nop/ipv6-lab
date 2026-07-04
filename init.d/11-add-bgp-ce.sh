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
!
router bgp 65002 vrf ce5
 bgp router-id 169.254.1.102
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 no bgp network import-check
 neighbor fd00:1:: remote-as 65001
 neighbor fd00:1:: update-source fd00:1::1
 neighbor fd00:1:: capability extended-nexthop
 !
 address-family ipv4 unicast
  neighbor fd00:1:: activate
  neighbor fd00:1:: as-override
  sid vpn export auto
  rd vpn export 65001:1003
  rt vpn both 65001:1003
  export vpn
  import vpn
 exit-address-family
 !
 address-family ipv6 unicast
  neighbor fd00:1:: activate
  neighbor fd00:1:: as-override
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
 !
 address-family ipv6 vpn
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
!
router bgp 65002 vrf ce6
 bgp router-id 169.254.2.102
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 no bgp network import-check
 neighbor fd00:1:1:: remote-as 65001
 neighbor fd00:1:1:: update-source fd00:1:1::1
 neighbor fd00:1:1:: capability extended-nexthop
 !
 address-family ipv4 unicast
  neighbor fd00:1:1:: activate
  neighbor fd00:1:1:: as-override
  sid vpn export auto
  rd vpn export 65001:1003
  rt vpn both 65001:1003
  export vpn
  import vpn
 exit-address-family
 !
 address-family ipv6 unicast
   neighbor fd00:1:1:: activate
   neighbor fd00:1:1:: as-override
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
 !
 address-family ipv6 vpn
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
ipv6 prefix-list allow-all6 seq 5 permit fd00::/8 ge 8 le 64
ipv6 prefix-list allow-self6 seq 5 permit fd00:1::/48 ge 48 le 48
!
router bgp 65001
 bgp router-id 169.254.1.101
 no bgp default ipv4-unicast
 no bgp network import-check
 neighbor fd00:1::1 remote-as 65002
 neighbor fd00:1::1 update-source fd00:1::
 neighbor fd00:1::1 capability extended-nexthop
 !
 address-family ipv4 unicast
  network 10.0.0.0/24
  neighbor fd00:1::1 activate
  neighbor fd00:1::1 prefix-list allow-all in
  neighbor fd00:1::1 prefix-list allow-self out
 exit-address-family
 !
 address-family ipv6 unicast
  network fd00:1::/48
  neighbor fd00:1::1 activate
  neighbor fd00:1::1 prefix-list allow-all6 in
  neighbor fd00:1::1 prefix-list allow-self6 out
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
ipv6 prefix-list allow-self6 seq 5 permit fd00:1:1::/48 ge 48 le 48
ipv6 prefix-list allow-all6 seq 5 permit fd00::/8 ge 8 le 64
!
router bgp 65001
 bgp router-id 169.254.2.101
 no bgp default ipv4-unicast
 no bgp network import-check
 neighbor fd00:1:1::1 remote-as 65002
 neighbor fd00:1:1::1 update-source fd00:1:1::
 neighbor fd00:1:1::1 capability extended-nexthop
 !
 address-family ipv4 unicast
  network 10.0.1.0/24
  neighbor fd00:1:1::1 activate
  neighbor fd00:1:1::1 prefix-list allow-all in
  neighbor fd00:1:1::1 prefix-list allow-self out
 exit-address-family
 !
 address-family ipv6 unicast
  network fd00:1:1::/48
  neighbor fd00:1:1::1 activate
  neighbor fd00:1:1::1 prefix-list allow-all6 in
  neighbor fd00:1:1::1 prefix-list allow-self6 out
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
