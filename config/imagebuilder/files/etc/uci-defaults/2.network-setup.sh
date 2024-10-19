#!/bin/sh

echo "Setup WAN and LAN Interface"
# Configure Network
uci set network.lan.ipaddr="192.168.1.1"
uci del network.lan.ip6assign
uci set network.tethering=interface
uci set network.tethering.proto='dhcp'
uci set network.tethering.device='usb0'
uci set network.tethering.metric='20'
uci set network.wan=interface
uci set network.wan.proto='dhcp'
uci set network.wan.device='eth1'
uci set network.wan.metric='1'
uci del network.wan6
uci commit network

# configure Firewall
uci set firewall.@zone[1].network='wan tethering'
uci commit firewall

# configure DHCP
uci del dhcp.@dnsmasq[0].nonwildcard
uci del dhcp.@dnsmasq[0].noresolv
uci del dhcp.@dnsmasq[0].boguspriv
uci del dhcp.@dnsmasq[0].filterwin2k
uci del dhcp.@dnsmasq[0].filter_aaaa
uci del dhcp.@dnsmasq[0].filter_a
uci del dhcp.@dnsmasq[0].nonegcache
uci add_list dhcp.@dnsmasq[0].server='1.1.1.1'
uci -q delete dhcp.lan.dhcpv6
uci -q delete dhcp.lan.ra
uci -q delete dhcp.lan.ndp
uci -q delete dhcp.lan.ra_slaac
uci -q delete dhcp.lan.ra_flags
uci commit dhcp
/etc/init.d/dnsmasq restart

# configure WLAN
# echo "Setup Wireless if available"
# uci set wireless.@wifi-device[0].disabled='0'
# uci set wireless.@wifi-iface[0].disabled='0'
# uci set wireless.@wifi-iface[0].encryption='none'
# uci set wireless.@wifi-device[0].country='ID'
# uci set wireless.@wifi-iface[0].ssid='OpenWrt'
# uci set wireless.@wifi-device[0].channel='1'
# uci set wireless.@wifi-device[0].band='2g'
# uci commit wireless
# wifi reload && wifi up

echo "Network setup complete!"
rm -- "$0"