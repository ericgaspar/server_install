#!/bin/bash

####################################################################################
#	LEMP server for Raspberry Pi                                               #
#	This script will install Nginx, PHP, Nodejs, MySQL, phpMyAdmin             #
#	7/11/2019                                                                  #
####################################################################################

# Verify that the script id run as ROOT
if [ "$(whoami)" != "root" ]; then
	echo "Run script as ROOT! (sudo bash install.sh)"
	exit
fi

# Solve Perl language issue
export LANGUAGE=fr_FR.UTF-8
export LANG=fr_FR.UTF-8
export LC_ALL=fr_FR.UTF-8
locale-gen fr_FR.UTF-8
dpkg-reconfigure locales

# Define user Domain Name, email, time-zone
echo "------------------------------------------------------------------------------"
echo " NGinx + PHP7-FPM + MySQL installation"
echo " This script will install a LEMP server on a Raspberry Pi"
echo "------------------------------------------------------------------------------"
read -p " Enter your Domain Name: " DOMAIN
echo "------------------------------------------------------------------------------"
read -p " Enter your Email Adress: " EMAIL
echo "------------------------------------------------------------------------------"
read -p " Do you want to change the time zone? <y/N> " prompt
echo "------------------------------------------------------------------------------"
echo
if [ "$prompt" = "y" ]; then
	dpkg-reconfigure tzdata
fi

# Update Raspberry Pi
apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y

# Update Raspberry Pi kernel
rpi-update

# Install complementary apps
apt-get install -y git vim acl

# NGinx PHP (dernière version). PHP7.3 ou NodeJS ?
apt-get install -y nginx php-fpm

update-rc.d nginx defaults
update-rc.d php7.3-fpm defaults

sed -i 's/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/7.3/fpm/php.ini
sed -i 's/# server_names_hash_bucket_size/server_names_hash_bucket_size/' /etc/nginx/nginx.conf

# Let's Encrypt (nginx must be stoped)
echo "------------------------------------------------------------------------------"
read -p " Do you want to run Let's Encrypt? <y/N>" prompt
echo "------------------------------------------------------------------------------"
if [ "$prompt" = "y" ]; then
	apt-get install -y certbot
	certbot certonly -m $EMAIL --agree-tos -n --force-renewal --authenticator standalone -d $DOMAIN -d www.$DOMAIN --pre-hook "service nginx stop" --post-hook "service nginx start"
fi

cat > /etc/nginx/sites-available/$DOMAIN.conf <<EOF
# $DOMAIN server configuration

# Expires map
map $sent_http_content_type $expires {
    default                    off;
    text/html                  7d;
    text/css                   max;
    application/javascript     max;
    ~image/                    max;
}

server {
	listen			80;
	listen			[::]:80;
	server_name		$DOMAIN www.$DOMAIN;
	return			301 https://$DOMAIN$request_uri;
}

server {
	listen			443 ssl http2;
	listen			[::]:443 ssl http2;
	server_name		www.$DOMAIN $DOMAIN;
	root			/var/www/$DOMAIN;
	index			index.php index.html index.htm;

    charset UTF-8; 
    
	# Pass the PHP scripts to FastCGI server
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/run/php/php7.3-fpm.sock;
	}

	# Optimize static file serving
	location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
		access_log off;
		log_not_found off;
		expires 60d;
	}

	# Compression
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

	# Improve HTTPS performance with session resumption
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 5m;

    # ssl
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/$DOMAIN/chain.pem;

    # Disable SSLv3 (TLSv1.3)
    ssl_protocols TLSv1.2; 

    # Enable server-side protection against BEAST attacks
    ssl_prefer_server_ciphers on;
  	ssl_session_tickets off;
    ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;
  	ssl_stapling on;
  	ssl_stapling_verify on;

    # Diffie-Hellman parameter for DHE ciphersuites
    # ssl_dhparam /etc/ssl/certs/dhparam.pem;
}
EOF

rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/$DOMAIN.conf /etc/nginx/sites-enabled/
mv /var/www/html /var/www/$DOMAIN
rm /var/www/$DOMAIN/index.nginx-debian.html
echo "<?php phpinfo(); ?>" > /var/www/$DOMAIN/index.php
nginx -t
systemctl start nginx
systemctl status nginx

# Set right access to www folder
usermod -a -G www-data pi
chown -R pi:www-data /var/www
chgrp -R www-data /var/www
chmod -R g+rw /var/www
setfacl -d -R -m g::rw /var/www

# Install Nodejs
curl -sL https://deb.nodesource.com/setup_13.x | sudo -E bash -
apt-get install -y nodejs

# Install MariaDB
echo "------------------------------------------------------------------------------"
read -p " Do you want to install MariaDB? <y/N> " prompt
echo "------------------------------------------------------------------------------"
if [ "$prompt" = "y" ]; then
    apt-get install -y mariadb-server mariadb-client
    mysql_secure_installation
fi

# Install PhpMyAdmin
echo "------------------------------------------------------------------------------"
read -p " Do you want to install phpMyAdmin? <y/N> " prompt
echo "------------------------------------------------------------------------------"
echo
if [ "$prompt" = "y" ]; then
	apt-get install -y phpmyadmin
	ln -s /usr/share/phpmyadmin /var/www/$DOMAIN
fi

# Wifi setup avec dongle usb
echo "------------------------------------------------------------------------------"
read -p " Do you want to configure wifi? <y/N> " prompt
if [ "$prompt" = "y" ]; then
echo "------------------------------------------------------------------------------"
read -p " Enter your SSID: " SSID
echo "------------------------------------------------------------------------------"
read -p " Enter your wifi key: " WIFIPASSWORD
echo "------------------------------------------------------------------------------"
cat > /etc/wpa_supplicant/wpa_supplicant.conf <<EOF
country=FR
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
network={
	ssid="$SSID"
	psk="$WIFIPASSWORD"
	key_mgmt=WPA-PSK
}
EOF
fi

# Fail2ban
apt-get install -y fail2ban
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
# éditer le jail local

# Install a firewall (may not be necessary)
#apt-get install -y ufw
#ufw enable

# Renew Let's Encrypt script (to be scripted)
#crontab -e
#30 3 * * 0 /opt/letsencrypt/letsencrypt-auto renew >> /var/log/letsencrypt/renewal.log

# Dhparam (take looong time on Raspberry pi)
#openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096

#Setting the DNS servers on your Raspberry Pi
#sudo nano /etc/dhcpcd.conf
#static domain_name_servers=8.8.4.4 8.8.8.8

#service dhcpcd restart
service nginx restart
service php7.3-fpm restart
service mysql restart
service fail2ban restart
apt-get autoremove -y
apt-get autoclean -y

# Summary
echo
echo "------------------------------------------------------------------------------"
echo "               NGinx + PHP7-FPM + MySQL installation finished"
echo "------------------------------------------------------------------------------"
echo " NGinx configuration folder:       /etc/nginx"
echo " NGinx default site configuration: /etc/nginx/sites-enabled/default"
echo " NGinx default HTML root:          /var/www/$DOMAIN"
echo " NGinx access logs:                /var/log/nginx/access.log"
echo " NGinx error logs:                 /var/log/nginx/error.log"
echo
echo " HTML page:                        $DOMAIN or `hostname -I`"
echo " Acces to phpMyAdmin:              $DOMAIN/phpmyadmin"
echo " User:                             root"
echo " Password:                         $mysqlPass"
echo
echo " php version:                      `php -v`"
echo " Nodejs version:                   `node -v`"
echo " npm version:                      `npm -v`"
echo "------------------------------------------------------------------------------"
read -p " Do you want to start raspi-config? <y/N> " prompt
if [ "$prompt" = "y" ]; then
	raspi-config
else
	reboot
fi
