#!/bin/sh

# Setting Hotspot


# Setup Network
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

# Setup Firewall
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
uci commit firewall

chmod +x /usr/bin/acct_log.sh
chmod +x /usr/bin/check_kuota.sh
chmod +x /usr/bin/client_check.sh
chmod +x /usr/bin/pear
chmod +x /usr/bin/peardev

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

chmod +x /etc/init.d/chilli
if ! grep -q '/etc/init.d/chilli restart' /etc/rc.local; then
    sed -i '/exit 0/i /etc/init.d/chilli restart' /etc/rc.local
fi


echo "Hotspot setup complete!"
rm -- "$0"

reboot