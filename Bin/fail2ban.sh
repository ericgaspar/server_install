#!/bin/sh


if [ "$(whoami)" != "root" ]; then
    echo "Run script as ROOT!"
    exit
fi


apt-get -y install fail2ban

service enable fail2ban
service start fail2ban

echo "Fail2ban up and ready"