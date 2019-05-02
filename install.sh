#!/bin/bash

if [ "$(whoami)" != "root" ]; then
	echo "Run script as ROOT ! (sudo bash install.sh)"
	exit
fi

# Ask for personnal Domain name
#read -p "What is you Domain Name ? : " DOMAIN
#echo
DOMAIN = "cuboctaedre.xyz"

# Solve Perl language
export LANGUAGE=fr_FR.UTF-8
export LANG=fr_FR.UTF-8
export LC_ALL=fr_FR.UTF-8
locale-gen fr_FR.UTF-8
dpkg-reconfigure locales

apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y

apt-get install -y rpi-update

apt-get install -y git vim acl

apt-get install -y nginx
apt-get install -y php7.0 php7.0-fpm php7.0-cli php7.0-opcache php7.0-mbstring php7.0-curl php7.0-xml php7.0-gd php7.0-mysql

update-rc.d nginx defaults
update-rc.d php7.0-fpm defaults

sed -i 's/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/7.0/fpm/php.ini
sed -i 's/# server_names_hash_bucket_size/server_names_hash_bucket_size/' /etc/nginx/nginx.conf

cat > /etc/nginx/sites-enabled/default << "EOF"
# Default server
server {
	listen 80 default_server;
	listen [::]:80 default_server;

#	listen 443 ssl http2 default_server;
#	listen [::]:443 ssl http2 default_server;
	
	server_name cuboctaedre.xyz;
	root /var/www/cuboctaedre.xyz;
	index index.php index.html index.htm default.html;

	location / {
		try_files $uri $uri/ =404;
	}

	# pass the PHP scripts to FastCGI server
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/run/php/php7.0-fpm.sock;
	}

	# optimize static file serving
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
    #   ssl_session_cache shared:SSL:10m;
    #   ssl_session_timeout 5m;

	# Enable server-side protection against BEAST attacks
    #    ssl_prefer_server_ciphers on;
    #    ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;

    # Disable SSLv3
    #   ssl_protocols TLSv1.1 TLSv1.2;

    # Diffie-Hellman parameter for DHE ciphersuites
    # $ sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
    #   ssl_dhparam /etc/ssl/certs/dhparam.pem;

	# deny access to .htaccess files, should an Apache document root conflict with nginx
	location ~ /\.ht {
		deny all;
	}
}
EOF

mkdir -p /var/www/$DOMAIN
cat > /var/www/$DOMAIN/index.php << "EOF"
<?php
class Application
{
	public function __construct()
	{
		phpinfo();
	}
}
$application = new Application();
EOF

rm -rf /var/www/html

usermod -a -G www-data pi
chown -R pi:www-data /var/www
chgrp -R www-data /var/www
chmod -R g+rw /var/www
setfacl -d -R -m g::rw /var/www

# MySQL
apt-get -y install mysql-server --fix-missing

read -s -p "Type the password for MySQL: " mysqlPass

mysql --user="root" --password="$mysqlPass" --database="mysql" --execute="GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$mysqlPass'; FLUSH PRIVILEGES;"

#sed -i 's/^bind-address/#bind-address/' /etc/mysql/mysql.conf.d/mysqld.cnf
#sed -i 's/^skip-networking/#skip-networking/' /etc/mysql/mysql.conf.d/mysqld.cnf

# PhpMyAdmin
read -p "Do you want to install PhpMyAdmin? <y/N> " prompt
if [ "$prompt" = "y" ]; then
	apt-get install -y phpmyadmin
	ln -s /usr/share/phpmyadmin /var/www/$DOMAIN
	echo "http://192.168.0.38/phpmyadmin or http://$DOMAIN/phpmyadmin to enter PhpMyAdmin"
fi

# Fail2ban
apt-get -y install fail2ban
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Let's Encrypt
apt-get install -y letsencrypt
letsencrypt certonly --webroot -w /var/www/$DOMAIN -d  $DOMAIN -d www.$DOMAIN

# Dhparam
# mkdir -p /etc/nginx/ssl
# openssl rand 48 -out /etc/nginx/ssl/ticket.key
# openssl dhparam -out /etc/nginx/ssl/dhparam4.pem 2048
# echo "ssl_dhparam /etc/nginx/ssl/dhparam4.pem;" >>  /etc/nginx/conf.d/$DOMAIN

service nginx restart
service php7.0-fpm restart
service mysql restart
service fail2ban restart

apt-get -y autoremove
apt-get -y autoclean

# Summary
echo ""
echo "------------------------------------------------------------------------------"
echo "               NGinx + PHP7-FPM + MySQL installation finished"
echo "------------------------------------------------------------------------------"
echo "NGinx configuration folder:       /etc/nginx"
echo "NGinx default site configuration: /etc/nginx/sites-enabled/default"
echo "NGinx default HTML root:          /var/www/$DOMAIN"
echo ""
echo "Installation script  log file:  $LOG_FILE"
echo ""
echo "Notes: If you use IpTables add the following rules"
echo "iptables -A INPUT -i lo -s localhost -d localhost -j ACCEPT"
echo "iptables -A OUTPUT -o lo -s localhost -d localhost -j ACCEPT"
echo "iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT"
echo "iptables -A INPUT  -p tcp --dport http -j ACCEPT"
echo ""
echo "------------------------------------------------------------------------------"
echo ""

read -p "Do you want to reboot? <y/N> " prompt
if [ "$prompt" = "y" ]; then
	reboot
else
	echo "The installation is finished"	
fi
