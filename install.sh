#!/bin/bash

####################################################################################
#	LEMP server for Raspberry Pi                                               #
#	This script will install Nginx, PHP, MySQL, phpMyAdmin                     #
#	6/5/2019                                                                   #
####################################################################################

if [ "$(whoami)" != "root" ]; then
	echo "Run script as ROOT ! (sudo bash install.sh)"
	exit
fi

#To do: define a new user name and password

# Define user Domain Name
echo "------------------------------------------------------------------------------"
echo " NGinx + PHP7-FPM + MySQL installation"
echo " This script will install a LEMP server on a Raspberry Pi"
echo "------------------------------------------------------------------------------"
read -p " Enter your Domain Name: " DOMAIN
echo "------------------------------------------------------------------------------"
echo
echo "------------------------------------------------------------------------------"
read -p " Enter your Email Adress: " EMAIL
echo "------------------------------------------------------------------------------"
echo

# Set time zone
echo "------------------------------------------------------------------------------"
read -p " Do you want to change the time zone? <y/N> " prompt
echo "------------------------------------------------------------------------------"
echo
if [ "$prompt" = "y" ]; then
	dpkg-reconfigure tzdata
fi

# Solve Perl language issue
export LANGUAGE=fr_FR.UTF-8
export LANG=fr_FR.UTF-8
export LC_ALL=fr_FR.UTF-8
locale-gen fr_FR.UTF-8
dpkg-reconfigure locales

# Update Raspberry Pi
apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get install -y rpi-update

apt-get install -y git vim letsencrypt acl

# NGinx
apt-get install -y nginx
apt-get install -y php7.0 php7.0-fpm php7.0-mbstring php7.0-curl php7.0-xml php7.0-gd php7.0-mysql

update-rc.d nginx defaults
update-rc.d php7.0-fpm defaults

sed -i 's/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/7.0/fpm/php.ini
sed -i 's/# server_names_hash_bucket_size/server_names_hash_bucket_size/' /etc/nginx/nginx.conf

cat > /etc/nginx/sites-available/$DOMAIN <<EOF
# Default server
server {
	listen 80 default_server;
	listen [::]:80 default_server;

	listen 443 ssl http2 default_server;
	listen [::]:443 ssl http2 default_server;
	
	server_name www.$DOMAIN $DOMAIN;
	root /var/www/$DOMAIN;
	index index.php index.html index.htm;

	location ~ /.well-known {
                allow all;
    }

	location / {
		try_files $uri $uri/ =404;
	}

	# Pass the PHP scripts to FastCGI server
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/run/php/php7.0-fpm.sock;
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
    #    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    #    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # Disable SSLv3
       ssl_protocols TLSv1.1 TLSv1.2;

	# Enable server-side protection against BEAST attacks
       ssl_prefer_server_ciphers on;
       ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;

    # Diffie-Hellman parameter for DHE ciphersuites
    # $ sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
    #   ssl_dhparam /etc/ssl/certs/dhparam.pem;

	# deny access to .htaccess files, should an Apache document root conflict with nginx
	#location ~ /\.ht {
	#	deny all;
	#}
}
EOF

ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN

mv /var/www/html /var/www/$DOMAIN
rm /var/www/$DOMAIN/index.nginx-debian.html
echo "<?php phpinfo(); ?>" > /var/www/$DOMAIN/index.php

nginx -t
/etc/init.d/nginx restart

usermod -a -G www-data pi
chown -R pi:www-data /var/www
chgrp -R www-data /var/www
chmod -R g+rw /var/www
setfacl -d -R -m g::rw /var/www

# MySQL
apt-get -y install mysql-server

echo "------------------------------------------------------------------------------"
read -s -p " Type the password for MySQL: " mysqlPass
echo "------------------------------------------------------------------------------"
echo
# Probleme to resolve
mysql --user=root --password="$mysqlPass" --execute="DROP USER 'root'@'localhost'; CREATE USER 'root'@'localhost' IDENTIFIED BY '$mysqlPass'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost';"
sed -i 's/^bind-address/#bind-address/' /etc/mysql/mariadb.cnf
sed -i 's/^skip-networking/#skip-networking/' /etc/mysql/mariadb.cnf

# PhpMyAdmin
echo "------------------------------------------------------------------------------"
read -p " Do you want to install phpMyAdmin? <y/N> " prompt
echo "------------------------------------------------------------------------------"
echo
if [ "$prompt" = "y" ]; then
	apt-get install -y phpmyadmin
	ln -s /usr/share/phpmyadmin /var/www/$DOMAIN
fi

# Install a firewall
#apt-get install -y ufw
#ufw enable
#ufw allow 'Nginx Full' -y
#ufw delete allow 'Nginx HTTP' -y

# Fail2ban
apt-get install -y fail2ban
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

cat > /etc/fail2ban/jail.local <<EOF
# Fail2Ban configuration file
[DEFAULT]
ignoreip = 127.0.0.1/8 78.193.28.136
maxretry = 3
bantime = 1200
findtime = 120
destemail = $EMAIL
sender = root@$DOMAIN

[sshd]
enabled = true
port    = ssh
filter   = sshd
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[sshd-ddos]
enabled = true

[recidive]
enabled = true

[phpmyadmin]

enabled = true
port = http,https
filter = phpmyadmin
action = iptables-multiport[name=PHPMYADMIN, port="http,https", protocol=tcp]
logpath = /var/log/nginx/access.log
bantime = 3600
findtime = 60
maxretry = 3
EOF

service fail2ban restart
fail2ban-client reload phpmyadmin

# Verify your Fail2ban configurations
fail2ban-client status

# Let's Encrypt
echo "------------------------------------------------------------------------------"
read -p " Do you want to run Let's encrypt? <y/N> " prompt
echo "------------------------------------------------------------------------------"
echo
if [ "$prompt" = "y" ]; then
	letsencrypt certonly --webroot -w /var/www/$DOMAIN -d $DOMAIN -d www.$DOMAIN
fi

#sed -i 's/#    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;/ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;/' /etc/nginx/sites-available/$DOMAIN
#sed -i 's/#    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;/ssl_certificate /etc/letsencrypt/live/$DOMAIN/privkey.pem;/' /etc/nginx/sites-available/$DOMAIN

# Renew Let's Encrypt script
#crontab -e
#30 3 * * 0 /opt/letsencrypt/letsencrypt-auto renew >> /var/log/letsencrypt/renewal.log

# Dhparam
#openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096

service nginx restart
service php7.0-fpm restart
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
echo "------------------------------------------------------------------------------"
read -p " Do you want to start raspi-config? <y/N> " prompt
if [ "$prompt" = "y" ]; then
	raspi-config
else
	echo "------------------------------------------------------------------------------"
	echo "                         Installation finished"
	echo "------------------------------------------------------------------------------"
fi
