#!/bin/bash

# -----------------------------------------------------------------------------
# Flow-label-based per-flow traffic steering.
#
# An nftables rule on pe1 hashes the IPv6 flow label into one of three marks
# (0/1/2); a policy rule per fwmark selects a routing table (1100/1101/1102),
# and each table points at an SRv6 inline-mode route that steers through a
# different column-1 P-router (p11 / p21 / p31). So three different flow labels
# land on three different SRv6 paths, all toward pe2's locator.
#
# Depends on test/02-traffic-steering.sh, which allocates the 2001:db8:3:101::
# source prefix on pe1's lo and waits for OSPF to propagate it.
# -----------------------------------------------------------------------------

# 1) nft: stamp fwmark = jhash(flowlabel) mod 3, and count per mark.
ip netns exec pe1 nft create table ip6 testtable6
ip netns exec pe1 nft create chain ip6 testtable6 testchain6 '{ type filter hook output priority filter ; }'
ip netns exec pe1 nft add rule ip6 testtable6 testchain6 meta mark set jhash ip6 flowlabel mod 3 seed 15345
ip netns exec pe1 nft add rule ip6 testtable6 testchain6 meta mark 0 ip6 daddr 2001:db8:1:501::/64 counter
ip netns exec pe1 nft add rule ip6 testtable6 testchain6 meta mark 1 ip6 daddr 2001:db8:1:501::/64 counter
ip netns exec pe1 nft add rule ip6 testtable6 testchain6 meta mark 2 ip6 daddr 2001:db8:1:501::/64 counter

# 2) policy rule: fwmark picks the steering table.
ip -n pe1 -6 rule add fwmark 0 table 1100
ip -n pe1 -6 rule add fwmark 1 table 1101
ip -n pe1 -6 rule add fwmark 2 table 1102

# 3) per-table SRv6 inline-mode steering routes (mirrors 02-traffic-steering.sh,
#    one table per flow-label bucket). The single End SID per path is the
#    column-1 P-router; after it the OSPF underlay forwards the packet on to pe2.
#       table 1100 -> p11  (2001:db8:1:201:1::)  via v-p11
#       table 1101 -> p21  (2001:db8:1:202:1::)  via v-p21
#       table 1102 -> p31  (2001:db8:1:203:1::)  via v-p31
ip -n pe1 -6 route add 2001:db8:1:501::/64 table 1100 encap seg6 mode inline segs 2001:db8:1:201:1:: dev v-p11
ip -n pe1 -6 route add 2001:db8:1:501::/64 table 1101 encap seg6 mode inline segs 2001:db8:1:202:1:: dev v-p21
ip -n pe1 -6 route add 2001:db8:1:501::/64 table 1102 encap seg6 mode inline segs 2001:db8:1:203:1:: dev v-p31

# 4) exercise it: three flow labels -> three marks -> three tables -> three paths.
ip netns exec pe1 ping -c2 -6 -F 0xffffa -I 2001:db8:3:101:: 2001:db8:1:501::
ip netns exec pe1 ping -c3 -6 -F 0xffffb -I 2001:db8:3:101:: 2001:db8:1:501::
ip netns exec pe1 ping -c5 -6 -F 0xffffd -I 2001:db8:3:101:: 2001:db8:1:501::

# 5) verify: per-mark counters + the three steering tables.
ip netns exec pe1 nft list ruleset
ip -n pe1 -6 route show table 1100
ip -n pe1 -6 route show table 1101
ip -n pe1 -6 route show table 1102

# expected nft ruleset:
# table ip6 testtable6 {
# 	chain testchain6 {
# 		type filter hook output priority filter; policy accept;
# 		meta mark set jhash @nh,8,24 & 0xfffff mod 3 seed 0x3bf1
# 		meta mark 0x00000000 ip6 daddr 2001:db8:1:501::/64 counter packets 3 bytes 312
# 		meta mark 0x00000001 ip6 daddr 2001:db8:1:501::/64 counter packets 5 bytes 520
# 		meta mark 0x00000002 ip6 daddr 2001:db8:1:501::/64 counter packets 2 bytes 208
# 	}
# }
#
# NB: we could skip nft entirely and match the flow label directly with an
# ip-rule mask, e.g. `ip -6 rule add not ...`. The nft route is kept here to
# make the jhash -> fwmark mapping observable via the counters above.
