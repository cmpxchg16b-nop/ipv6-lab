#!/bin/bash

# assign a temporary address to loopback interface of PE1
ip -n pe1 a add 2001:db8:3:101::/64 dev lo

# awaiting OSPF propagation
sleep 3

# ping PE2 use the newly assigned address, look at the latency numbers
ip netns exec pe1 ping -c20 -I 2001:db8:3:101:: 2001:db8:1:501::

# traceroute to PE2, watch the forwarding path
ip netns exec pe1 traceroute -n -s 2001:db8:3:101:: 2001:db8:1:501::

# add traffic steering route based on SRv6 inline-mode, that is: a SRH IPv6 next-header will be injected into the header
ip -n pe1 -6 rule add from 2001:db8:3:101::/64 lookup 1001
ip -n pe1 -6 route add 2001:db8:1:501::/64 table 1001 encap seg6 mode inline segs 2001:db8:1:201:1::,2001:db8:1:303:1::,2001:db8:1:401:1:: dev v-p11

# do all the tests again:
ip netns exec pe1 ping -c20 -I 2001:db8:3:101:: 2001:db8:1:501::
ip netns exec pe1 traceroute -n -s 2001:db8:3:101:: 2001:db8:1:501::
