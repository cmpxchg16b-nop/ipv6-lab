#!/bin/bash

ip netns exec pe1 nft create table ip6 testtable6
ip netns exec pe1 nft create chain ip6 testtable6 testchain6 '{ type filter hook output priority filter ; }'

ip netns exec pe1 nft add rule ip6 testtable6 testchain6 meta mark set jhash ip6 flowlabel mod 3 seed 15345

ip netns exec pe1 nft add rule ip6 testtable6 testchain6 meta mark 0 ip6 daddr 2001:db8:1:501::/64 counter
ip netns exec pe1 nft add rule ip6 testtable6 testchain6 meta mark 1 ip6 daddr 2001:db8:1:501::/64 counter
ip netns exec pe1 nft add rule ip6 testtable6 testchain6 meta mark 2 ip6 daddr 2001:db8:1:501::/64 counter

ip netns exec pe1 ping -c2 -6 -F 0xffffa -I 2001:db8:3:101:: 2001:db8:1:501::
ip netns exec pe1 ping -c3 -6 -F 0xffffb -I 2001:db8:3:101:: 2001:db8:1:501::
ip netns exec pe1 ping -c5 -6 -F 0xffffd -I 2001:db8:3:101:: 2001:db8:1:501::

ip netns exec pe1 nft list ruleset

# expected
# table ip6 testtable6 {
# 	chain testchain6 {
# 		type filter hook output priority filter; policy accept;
# 		meta mark set jhash @nh,8,24 & 0xfffff mod 3 seed 0x3bf1
# 		meta mark 0x00000000 ip6 daddr 2001:db8:1:501::/64 counter packets 3 bytes 312
# 		meta mark 0x00000001 ip6 daddr 2001:db8:1:501::/64 counter packets 5 bytes 520
# 		meta mark 0x00000002 ip6 daddr 2001:db8:1:501::/64 counter packets 2 bytes 208
# 	}
# }

# actually, we can completely skip the nftable-based fwmark calculation steps,
# and head straight to ip-rule's masking flowlabel selector.

ip -n pe1 -6 rule add fwmark 0 table 1100
ip -n pe1 -6 rule add fwmark 1 table 1101
ip -n pe1 -6 rule add fwmark 2 table 1102
