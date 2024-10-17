#!/bin/sh

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

# Set login root password
# (echo "rtawrt"; sleep 1; echo "rtawrt") | passwd > /dev/null

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
uci set network.hotspot=device
uci set network.hotspot.name='br-hotspot'
uci set network.hotspot.type='bridge'
uci set network.hotspot.ipv6='0'
uci set network.voucher=interface
uci set network.voucher.name='voucher'
uci set network.voucher.proto='static'
uci set network.voucher.device='br-hotspot'
uci set network.voucher.ipaddr='10.10.30.1'
uci set network.voucher.netmask='255.255.255.0'
uci set network.chilli=interface
uci set network.chilli.proto='none'
uci set network.chilli.device='tun0'
uci commit network

# configure Firewall
uci set firewall.tun=zone
uci set firewall.tun.name='tun'
uci set firewall.tun.input='ACCEPT'
uci set firewall.tun.output='ACCEPT'
uci set firewall.tun.forward='REJECT'
uci add_list firewall.tun.network='chilli'
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='tun'
uci set firewall.@forwarding[-1].dest='wan'
uci set firewall.@zone[0].network='lan voucher'
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

# configure Theme
echo "Setup Default Theme"
uci set luci.main.mediaurlbase='/luci-static/material' && uci commit

# remove login password required when accessing terminal
uci set ttyd.@ttyd[0].command='/bin/bash --login'
uci commit

# Setting Tinyfm
ln -s / /www/tinyfm/rootfs

# Setting Hotspot
chmod +x /usr/bin/acct_log.sh
chmod +x /usr/bin/check_kuota.sh
chmod +x /usr/bin/client_check.sh
chmod +x /usr/bin/pear
chmod +x /usr/bin/peardev

sed -i -E "s|memory_limit = [0-9]+M|memory_limit = 100M|g" /etc/php.ini
sed -i -E "s|display_errors = On|display_errors = Off|g" /etc/php.ini
uci set uhttpd.main.index_page='index.php'
uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
uci commit uhttpd
/etc/init.d/uhttpd restart
ln -s /usr/bin/php-cli /usr/bin/php

sed -i -E "s|option enabled '0'|option enabled '1'|g" /etc/config/mysqld
sed -i -E "s|# datadir		= /srv/mysql|datadir	= /usr/share/mysql|g" /etc/mysql/conf.d/50-server.cnf
sed -i -E "s|127.0.0.1|0.0.0.0|g" /etc/mysql/conf.d/50-server.cnf
/etc/init.d/mysqld restart
/etc/init.d/mysqld reload
mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('radius');"
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'radius';"
mysql -u root -p"radius" <<EOF
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;
EOF
mysql -u root -p"radius" -e "CREATE DATABASE radius CHARACTER SET utf8";
mysql -u root -p"radius" -e "GRANT ALL ON radius.* TO 'radius'@'localhost' IDENTIFIED BY 'radius' WITH GRANT OPTION";
mysql -u root -p"radius" radius -e "SET FOREIGN_KEY_CHECKS = 0; $(mysql -u root -p"radius" radius -e 'SHOW TABLES' | awk '{print "DROP TABLE IF EXISTS `" $1 "`;"}' | grep -v '^Tables' | tr '\n' ' ') SET FOREIGN_KEY_CHECKS = 1;"
mysql -u root -p"radius" radius < /usr/share/radius_monitor.sql
rm -rf /usr/share/radius_monitor.sql

/etc/init.d/radiusd stop
rm -rf /etc/freeradius3
cd /root/hotspot/etc
mv freeradius3 /etc/freeradius3
rm -rf /usr/share/freeradius3
cd /root/hotspot/usr/share
mv freeradius3 /usr/share/freeradius3
cd /etc/freeradius3/mods-enabled
ln -s ../mods-available/always
ln -s ../mods-available/attr_filter
ln -s ../mods-available/chap
ln -s ../mods-available/detail
ln -s ../mods-available/digest
ln -s ../mods-available/eap
ln -s ../mods-available/exec
ln -s ../mods-available/expiration
ln -s ../mods-available/expr
ln -s ../mods-available/files
ln -s ../mods-available/logintime
ln -s ../mods-available/mschap
ln -s ../mods-available/pap
ln -s ../mods-available/preprocess
ln -s ../mods-available/radutmp
ln -s ../mods-available/realm
ln -s ../mods-available/sql
ln -s ../mods-available/sradutmp
ln -s ../mods-available/unix
cd /etc/freeradius3/sites-enabled
ln -s ../sites-available/default
ln -s ../sites-available/inner-tunnel
if ! grep -q '/etc/init.d/radiusd restart' /etc/rc.local; then
    sed -i '/exit 0/i /etc/init.d/radiusd restart' /etc/rc.local
fi

/etc/init.d/chilli stop
rm -rf /etc/config/chilli
rm -rf /etc/init.d/chilli
mv /root/hotspot/etc/config/chilli /etc/config/chilli
mv /root/hotspot/etc/init.d/chilli /etc/init.d/chilli

chmod +x /etc/init.d/chilli
if ! grep -q '/etc/init.d/chilli restart' /etc/rc.local; then
    sed -i '/exit 0/i /etc/init.d/chilli restart' /etc/rc.local
fi

echo "src/gz mutiara_wrt https://raw.githubusercontent.com/maizil41/mutiara-wrt-opkg/main/generic" >> /etc/opkg/customfeeds.conf

echo "All first boot setup complete!"
touch /etc/hotspotsetup
echo "All first boot setup complete!"
rm -rf /etc/uci-defaults/10.first-setup-boot.sh
reboot
exit 0