#!/bin/bash

echo "Starting Container ..."

# Get environment variables to show up in SSH session and USER tty
printenv | sed 's/\"/\\\"/g' | sed 's/\$/\\\$/g' | sed -e 's/^/export /g' | sed -e 's/=/=\"/g' | sed -e 's/$/\"/g' >> /etc/profile
printenv | sed 's/\"/\\\"/g' | sed 's/\$/\\\$/g' | sed -e 's/^/export /g' | sed -e 's/=/=\"/g' | sed -e 's/$/\"/g' >> /etc/bash.bashrc

test ! -d /home/LogFiles && mkdir /home/LogFiles
test ! -f /home/LogFiles/nginx-access.log && touch /home/LogFiles/nginx-access.log
test ! -f /home/LogFiles/nginx-error.log && touch /home/LogFiles/nginx-error.log
test ! -f /home/LogFiles/php7.1-fpm.log && touch /home/LogFiles/php7.1-fpm.log
test ! -d /home/LogFiles/supervisor && mkdir /home/LogFiles/supervisor

chown -R nobody:nogroup /home/LogFiles

mkdir -p /run/php && touch /run/php/php7.1-fpm.sock && chown -R nobody:nogroup /run/php

sed -i "s|loglevel=.*|loglevel=${SUPERVISOR_LOG_LEVEL:-warn}|" /etc/supervisor/conf.d/00-supervisord.conf
rm -rf /var/log/supervisor
ln -s /home/LogFiles/supervisor /var/log/supervisor

if [ ${DEBUG:-0} == 1 ]; then
    ln -sf /dev/stdout /var/log/nginx/access.log
    ln -sf /dev/stderr /var/log/nginx/error.log
    ln -sf /dev/stderr /var/log/php7.1-fpm.log
else
    ln -sf /home/LogFiles/nginx-access.log /var/log/nginx/access.log
    ln -sf /home/LogFiles/nginx-error.log /var/log/nginx/error.log
    ln -sf /home/LogFiles/php7.1-fpm.log /var/log/php7.1-fpm.log
fi

/usr/bin/supervisord
