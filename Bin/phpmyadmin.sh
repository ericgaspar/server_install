#!/bin/sh


if [ "$(whoami)" != "root" ]; then
    echo "Run script as ROOT!"
    exit
fi

# --PHPmyAdmin install------------------------------------------------

read -r -p "Do you want to install PHPmyadmin? [Y/n] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
	read -p " Enter password for phpmyadmin: " PASSWORD
    DEBIAN_FRONTEND=noninteractive apt-get -yq install phpmyadmin
	ln -s /usr/share/phpmyadmin /var/www/$DOMAIN
	mysql
	SELECT user,authentication_string,plugin,host FROM mysql.user;
	ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$PASSWORD';
	FLUSH PRIVILEGES;
	SELECT user,authentication_string,plugin,host FROM mysql.user;
	exit
else
    exit 0
fi