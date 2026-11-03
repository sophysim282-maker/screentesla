#!/bin/bash
set -euo pipefail
ip netns add slphonebrowser
ip netns add slrouter
ip netns add slbrowser
ip link add slphone type veth peer name slup
ip link set slup netns slrouter
ip link set slphone netns slphonebrowser
ip -n slphonebrowser addr add 172.20.10.1/24 dev slphone
ip -n slphonebrowser link set slphone up
ip -n slphonebrowser link set lo up
ip -n slphonebrowser route add default via 172.20.10.4
ip -n slrouter addr add 172.20.10.4/24 dev slup
ip -n slrouter link set slup up
ip link add sllan type veth peer name slcar
ip link set sllan netns slrouter
ip link set slcar netns slbrowser
ip -n slrouter addr add 192.168.93.1/24 dev sllan
ip -n slrouter link set sllan up
ip -n slrouter link set lo up
ip -n slbrowser addr add 192.168.93.142/24 dev slcar
ip -n slbrowser link set slcar up
ip -n slbrowser link set lo up
ip -n slbrowser route add default via 192.168.93.1
ip netns exec slrouter sysctl -w net.ipv4.ip_forward=1
ip netns exec slrouter iptables -P FORWARD DROP
ip netns exec slrouter iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip netns exec slrouter iptables -A FORWARD -i sllan -o slup -j ACCEPT
ip netns exec slrouter iptables -t nat -A POSTROUTING -s 192.168.93.0/24 -o slup -j MASQUERADE
ip netns exec slphonebrowser iptables -I INPUT -i slphone -j ACCEPT
