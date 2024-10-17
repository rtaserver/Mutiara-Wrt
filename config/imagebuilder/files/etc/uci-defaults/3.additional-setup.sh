#!/bin/sh

# configure Theme
echo "Setup Default Theme"
uci set luci.main.mediaurlbase='/luci-static/material' && uci commit

# remove login password required when accessing terminal
uci set ttyd.@ttyd[0].command='/bin/bash --login'
uci commit

# Setting Tinyfm
ln -s / /www/tinyfm/rootfs

# Settup PHP
sed -i -E "s|memory_limit = [0-9]+M|memory_limit = 100M|g" /etc/php.ini
sed -i -E "s|display_errors = On|display_errors = Off|g" /etc/php.ini
uci set uhttpd.main.index_page='index.php'
uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
uci commit uhttpd
/etc/init.d/uhttpd restart
ln -s /usr/bin/php-cli /usr/bin/php

echo "Additional setup complete!"
rm -- "$0"
reboot
exit 0