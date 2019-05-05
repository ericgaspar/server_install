#!/bin/bash

####################################################################################
#	LEMP server for Raspberry Pi                                               #
#	This script will install Nginx, PHP, MySQL, phpMyAdmin                     #
#	4/5/2019                                                                   #
####################################################################################

if [ "$(whoami)" != "root" ]; then
	echo "Run script as ROOT ! (sudo bash install.sh)"
	exit
fi

# Define user Domain Name
echo "------------------------------------------------------------------------------"
echo " NGinx + PHP7-FPM + MySQL installation"
echo " This script will install a LEMP server on a Raspberry Pi"
echo "------------------------------------------------------------------------------"
read -p " Enter your Domain Name: " DOMAIN
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
# https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-debian-9#step-5-–-setting-up-server-blocks
apt-get install -y nginx
apt-get install -y php7.0 php7.0-fpm php7.0-cli php7.0-opcache php7.0-mbstring php7.0-curl php7.0-xml php7.0-gd php7.0-mysql

update-rc.d nginx defaults
update-rc.d php7.0-fpm defaults

sed -i 's/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/7.0/fpm/php.ini
sed -i 's/# server_names_hash_bucket_size/server_names_hash_bucket_size/' /etc/nginx/nginx.conf

cat > /etc/nginx/sites-available/$DOMAIN <<EOF
# Default server
server {
	listen 80 default_server;
	listen [::]:80 default_server;

	#listen 443 ssl http2 default_server;
	#listen [::]:443 ssl http2 default_server;
	
	server_name www.$DOMAIN $DOMAIN;
	root /var/www/$DOMAIN;
	index index.php index.html index.htm;

	#location ~ /.well-known {
    #            allow all;
    #}

	#location / {
	#	try_files $uri $uri/ =404;
	#}

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

mkdir -p /var/www/$DOMAIN
rm -rf /var/www/html
rm -rf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
cat > /var/www/$DOMAIN/index.php << "EOF"
<?php
  phpinfo();
?>
EOF

nginx -t
service nginx reload

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
mysql --user=root --password="$mysqlPass" --database="mysql" --execute="DROP USER 'root'@'localhost'; CREATE USER 'root'@'localhost' IDENTIFIED BY '$mysqlPass'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost';"
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


# Let's Encrypt
# https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-debian-9
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
