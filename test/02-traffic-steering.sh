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

# If you like, you may run some statistical analysis on the following data:
# Appendixes: Samples of data
# Control group: Before detour TE is on
# ip netns exec pe1 ping -i 0.2 -c 50 -I 2001:db8:3:101:: 2001:db8:1:501::
# PING 2001:db8:1:501::(2001:db8:1:501::) from 2001:db8:3:101:: : 56 data bytes
# 64 bytes from 2001:db8:1:501::: icmp_seq=1 ttl=61 time=0.100 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=2 ttl=61 time=0.104 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=3 ttl=61 time=0.113 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=4 ttl=61 time=0.118 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=5 ttl=61 time=0.116 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=6 ttl=61 time=0.104 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=7 ttl=61 time=0.117 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=8 ttl=61 time=0.106 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=9 ttl=61 time=0.127 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=10 ttl=61 time=0.125 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=11 ttl=61 time=0.112 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=12 ttl=61 time=0.108 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=13 ttl=61 time=0.115 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=14 ttl=61 time=0.115 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=15 ttl=61 time=0.114 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=16 ttl=61 time=0.136 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=17 ttl=61 time=0.129 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=18 ttl=61 time=0.119 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=19 ttl=61 time=0.117 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=20 ttl=61 time=0.118 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=21 ttl=61 time=0.105 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=22 ttl=61 time=0.114 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=23 ttl=61 time=0.109 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=24 ttl=61 time=0.107 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=25 ttl=61 time=0.118 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=26 ttl=61 time=0.114 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=27 ttl=61 time=0.109 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=28 ttl=61 time=0.118 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=29 ttl=61 time=0.115 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=30 ttl=61 time=0.115 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=31 ttl=61 time=0.117 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=32 ttl=61 time=0.106 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=33 ttl=61 time=0.115 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=34 ttl=61 time=0.118 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=35 ttl=61 time=0.127 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=36 ttl=61 time=0.124 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=37 ttl=61 time=0.113 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=38 ttl=61 time=0.117 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=39 ttl=61 time=0.132 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=40 ttl=61 time=0.122 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=41 ttl=61 time=1.01 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=42 ttl=61 time=0.109 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=43 ttl=61 time=0.112 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=44 ttl=61 time=0.117 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=45 ttl=61 time=0.119 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=46 ttl=61 time=0.115 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=47 ttl=61 time=0.104 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=48 ttl=61 time=0.113 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=49 ttl=61 time=0.125 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=50 ttl=61 time=0.121 ms

# --- 2001:db8:1:501:: ping statistics ---
# 50 packets transmitted, 50 received, 0% packet loss, time 10011ms
# rtt min/avg/max/mdev = 0.100/0.133/1.011/0.125 ms
# ip netns exec pe1 traceroute -n -s 2001:db8:3:101:: 2001:db8:1:501::
# traceroute to 2001:db8:1:501:: (2001:db8:1:501::), 30 hops max, 80 byte packets
#  1  2001:db8:1:101::201:1  0.053 ms  0.010 ms  0.008 ms
#  2  2001:db8:1:201::301:1  0.034 ms  0.010 ms  0.010 ms
#  3  2001:db8:1:301::401:1  0.035 ms  0.011 ms  0.010 ms
#  4  2001:db8:1:501::  0.030 ms  0.013 ms  0.011 ms
#
#
#
# Treatment group: when detour TE is activated
# ip netns exec pe1 ping -i 0.2 -c 50 -I 2001:db8:3:101:: 2001:db8:1:501::
# PING 2001:db8:1:501::(2001:db8:1:501::) from 2001:db8:3:101:: : 56 data bytes
# 64 bytes from 2001:db8:1:501::: icmp_seq=1 ttl=61 time=0.160 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=2 ttl=61 time=0.436 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=3 ttl=61 time=0.157 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=4 ttl=61 time=0.177 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=5 ttl=61 time=0.171 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=6 ttl=61 time=0.220 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=7 ttl=61 time=0.169 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=8 ttl=61 time=0.215 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=9 ttl=61 time=0.152 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=10 ttl=61 time=0.163 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=11 ttl=61 time=0.212 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=12 ttl=61 time=0.230 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=13 ttl=61 time=0.162 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=14 ttl=61 time=0.162 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=15 ttl=61 time=0.159 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=16 ttl=61 time=0.168 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=17 ttl=61 time=0.160 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=18 ttl=61 time=0.177 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=19 ttl=61 time=0.168 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=20 ttl=61 time=0.177 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=21 ttl=61 time=0.172 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=22 ttl=61 time=0.168 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=23 ttl=61 time=0.168 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=24 ttl=61 time=0.168 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=25 ttl=61 time=0.194 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=26 ttl=61 time=0.169 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=27 ttl=61 time=0.161 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=28 ttl=61 time=0.157 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=29 ttl=61 time=0.154 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=30 ttl=61 time=0.163 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=31 ttl=61 time=0.171 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=32 ttl=61 time=0.155 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=33 ttl=61 time=0.163 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=34 ttl=61 time=0.150 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=35 ttl=61 time=0.177 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=36 ttl=61 time=0.163 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=37 ttl=61 time=0.163 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=38 ttl=61 time=0.167 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=39 ttl=61 time=0.156 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=40 ttl=61 time=0.162 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=41 ttl=61 time=0.162 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=42 ttl=61 time=0.148 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=43 ttl=61 time=0.158 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=44 ttl=61 time=0.474 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=45 ttl=61 time=0.191 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=46 ttl=61 time=0.178 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=47 ttl=61 time=0.170 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=48 ttl=61 time=0.164 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=49 ttl=61 time=0.164 ms
# 64 bytes from 2001:db8:1:501::: icmp_seq=50 ttl=61 time=0.178 ms

# --- 2001:db8:1:501:: ping statistics ---
# 50 packets transmitted, 50 received, 0% packet loss, time 10003ms
# rtt min/avg/max/mdev = 0.148/0.181/0.474/0.058 ms
# ip netns exec pe1 traceroute -n -s 2001:db8:3:101:: 2001:db8:1:501::
# traceroute to 2001:db8:1:501:: (2001:db8:1:501::), 30 hops max, 80 byte packets
#  1  2001:db8:1:101::201:1  0.067 ms  0.011 ms  0.011 ms
#  2  2001:db8:3:101::  0.025 ms  0.011 ms  0.009 ms
#  3  2001:db8:1:101::203:1  0.038 ms  0.011 ms  0.011 ms
#  4  2001:db8:1:203::303:1  0.039 ms  0.014 ms  0.013 ms
#  5  2001:db8:1:303::403:1  0.036 ms  0.015 ms  0.016 ms
#  6  2001:db8:1:403::501:1  0.073 ms  0.041 ms  0.021 ms
#  7  2001:db8:1:401::501:0  0.031 ms  0.019 ms  0.018 ms
#  8  2001:db8:1:501::  0.023 ms  0.019 ms  0.018 ms
