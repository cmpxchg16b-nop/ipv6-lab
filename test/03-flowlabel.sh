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
ip netns exec pe1 nft create chain ip6 testtable6 testchain6 '{ type route hook output priority mangle ; policy accept ; }'
ip netns exec pe1 nft add rule ip6 testtable6 testchain6 meta mark set jhash ip6 flowlabel mod 3 seed 15345

# 2) policy rule: fwmark picks the steering table.

# assign a temporary address to loopback interface of PE1
ip -n pe1 a add 2001:db8:3:101::/64 dev lo

# awaiting OSPF propagation
sleep 3

ip -n pe1 -6 rule add from 2001:db8:3::/48 fwmark 0/0xffffffff table 1100
ip -n pe1 -6 rule add from 2001:db8:3::/48 fwmark 1/0xffffffff table 1101
ip -n pe1 -6 rule add from 2001:db8:3::/48 fwmark 2/0xffffffff table 1102
ip -n pe1 -6 route flush cache

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
# 0xffffa mark should be 2
# 0xffffb mark should be 0
# 0xffffd mark should be 1

ip netns exec pe1 traceroute --flowlabel=0xffffa -s 2001:db8:3:101:: 2001:db8:1:501::
# expected output:
# traceroute to 2001:db8:1:501:: (2001:db8:1:501::), 30 hops max, 80 byte packets
#  1  2001:db8:1:101::203:1 (2001:db8:1:101::203:1)  0.086 ms  0.013 ms  0.012 ms
#  2  2001:db8:1:203::303:1 (2001:db8:1:203::303:1)  0.044 ms  0.014 ms  0.013 ms
#  3  2001:db8:1:303::403:1 (2001:db8:1:303::403:1)  0.037 ms  0.015 ms  0.014 ms
#  4  2001:db8:1:501:: (2001:db8:1:501::)  0.065 ms  0.020 ms  0.021 ms

ip netns exec pe1 traceroute --flowlabel=0xffffb -s 2001:db8:3:101:: 2001:db8:1:501::
# expected output:
# traceroute to 2001:db8:1:501:: (2001:db8:1:501::), 30 hops max, 80 byte packets
#  1  2001:db8:1:101::201:1 (2001:db8:1:101::201:1)  0.192 ms  0.021 ms  0.051 ms
#  2  2001:db8:1:201::301:1 (2001:db8:1:201::301:1)  0.059 ms  0.013 ms  0.012 ms
#  3  2001:db8:1:301::401:1 (2001:db8:1:301::401:1)  0.035 ms  0.014 ms  0.014 ms
#  4  2001:db8:1:501:: (2001:db8:1:501::)  0.032 ms  0.017 ms  0.017 ms

ip netns exec pe1 traceroute --flowlabel=0xffffd -s 2001:db8:3:101:: 2001:db8:1:501::
# expected output:
# traceroute to 2001:db8:1:501:: (2001:db8:1:501::), 30 hops max, 80 byte packets
#  1  2001:db8:1:101::202:1 (2001:db8:1:101::202:1)  0.094 ms  0.018 ms  0.011 ms
#  2  2001:db8:1:202::302:1 (2001:db8:1:202::302:1)  0.040 ms  0.014 ms  0.013 ms
#  3  2001:db8:1:302::402:1 (2001:db8:1:302::402:1)  0.124 ms  0.034 ms  0.029 ms
#  4  2001:db8:1:501:: (2001:db8:1:501::)  0.182 ms  0.098 ms  0.039 ms

# so, as we can see, that the first hop diverts, based on the flowlabel provided.
