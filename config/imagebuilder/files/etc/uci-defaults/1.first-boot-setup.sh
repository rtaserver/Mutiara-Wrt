#!/bin/sh

# Set login root password
# (echo "rtawrt"; sleep 1; echo "rtawrt") | passwd > /dev/null

# Fixed Wifi
chmod +x /lib/netifd/proto/3g.sh
chmod +x /lib/netifd/proto/dhcp.sh
chmod +x /lib/netifd/proto/dhcpv6.sh
chmod +x /lib/netifd/proto/ppp.sh
chmod +x /lib/netifd/dhcp-get-server.sh
chmod +x /lib/netifd/dhcp.script
chmod +x /lib/netifd/dhcpv6.script
chmod +x /lib/netifd/hostapd.sh
chmod +x /lib/netifd/netifd-proto.sh
chmod +x /lib/netifd/netifd-wireless.sh
chmod +x /lib/netifd/ppp-down
chmod +x /lib/netifd/ppp-up
chmod +x /lib/netifd/ppp6-up
chmod +x /lib/netifd/utils.sh
chmod +x /lib/wifi/mac80211.sh

# Set hostname and Timezone to Asia/Jakarta
echo "Setup NTP Server and Time Zone to Asia/Jakarta"
uci set system.@system[0].hostname='RTA-WRT'
uci set system.@system[0].timezone='WIB-7'
uci set system.@system[0].zonename='Asia/Jakarta'
uci -q delete system.ntp.server
uci add_list system.ntp.server="pool.ntp.org"
uci add_list system.ntp.server="id.pool.ntp.org"
uci add_list system.ntp.server="time.google.com"
uci commit system


# Add Custom Feeds
sed -i 's/option check_signature/# option check_signature/g' /etc/opkg.conf
echo "src/gz mutiara_wrt https://raw.githubusercontent.com/maizil41/mutiara-wrt-opkg/main/generic" >> /etc/opkg/customfeeds.conf

echo "First setup complete!"
rm -- "$0"