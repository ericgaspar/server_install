#!/bin/sh


if [ "$(whoami)" != "root" ]; then
    echo "Run script as ROOT!"
    exit
fi

# --MariaDB install---------------------------------------------------

read -r -p "Do you want to install MariaDB? [Y/n] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
    apt-get install -y mariadb-server mariadb-client
    mysql_secure_installation
else
    exit 0
fi