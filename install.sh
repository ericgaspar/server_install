#!/bin/bash
#===============================================================================
#
#         USAGE: curl https://raw.githubusercontent.com/ericgaspar/server_install/master/install.sh
#                 AND
#                sudo bash install.sh
#
#   DESCRIPTION: Server Installer Script.
#
#                This script will install Nginx, PHP, MySQL, phpMyAdmin
#
#          BUGS: phpmyadmin password...
#
#       CREATED: 05/04/2020 
#
#      REVISION: 0.2
#===============================================================================

# Verify that the script id run as ROOT
if [ "$(whoami)" != "root" ]; then
    echo "Run script as ROOT! (sudo bash install.sh)"
    exit
fi

print_banner() {
  cat <<-'EOF'
=================================================
              
 ____ 
|  _ \ __ _ ___ _ __ | |__   ___ _ __ _ __ _   _ 
| |_) / _` / __| '_ \| '_ \ / _ \ '__| '__| | | |
|  _ < (_| \__ \ |_) | |_) |  __/ |  | |  | |_| |
|_| \_\__,_|___/ .__/|_.__/ \___|_|  |_|   \__, |
               |_|                         |___/       
          ____                                     
         / ___|  ___ _ ____   _____ _ __ 
         \___ \ / _ \ '__\ \ / / _ \ '__|
          ___) |  __/ |   \ V /  __/ |  
         |____/ \___|_|    \_/ \___|_| 
                                                                       
       ___           _        _ _           
      |_ _|_ __  ___| |_ __ _| | | ___ _ __ 
       | || '_ \/ __| __/ _` | | |/ _ \ '__|
       | || | | \__ \ || (_| | | |  __/ |   
      |___|_| |_|___/\__\__,_|_|_|\___|_|   

                                      
==================================================
EOF
}


USER=$(whoami)

# Ask for a new password
passwd

# Set password for phpmyadmin
while true; do
    read -s -p "Password: " PASSWORD
    echo
    read -s -p "Password (again): " PASSWORD2
    echo
    [ "$PASSWORD" = "$PASSWORD2" ] && break
    echo "Please try again"
done

# Solve Perl language issue
# Should not be interactive
    #export LANGUAGE=fr_FR.UTF-8
    #export LANG=fr_FR.UTF-8
    #export LC_ALL=fr_FR.UTF-8
    #locale-gen fr_FR.UTF-8
    #dpkg-reconfigure locales

    #localectl set-locale LANG=fr_FR.UTF-8

# Set language locals
perl -$USER -e 's/# fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/g' /etc/locale.gen

# Define user Domain Name, email
echo "------------------------------------------------------------------------------"
echo " NGinx + PHP7-FPM + MySQL installation"
echo " This script will install a LEMP server on a Raspberry Pi"
echo "------------------------------------------------------------------------------"
read -p " Enter your Domain Name: " DOMAIN
echo "------------------------------------------------------------------------------"
read -p " Enter your Email Adress: " EMAIL
echo "------------------------------------------------------------------------------"

# Set the time-Zone to Europe/Paris
rm /etc/localtime
ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime
rm /etc/timezone

# Update server systeme
apt-get update -y && apt-get upgrade -y
apt-get dist-upgrade -y

# Install complementary apps
apt-get install -y nginx php-fpm git vim acl proftpd net-tools

update-rc.d nginx defaults
update-rc.d php7.3-fpm defaults

sed -i 's/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/7.3/fpm/php.ini
sed -i 's/# server_names_hash_bucket_size/server_names_hash_bucket_size/' /etc/nginx/nginx.conf

# Let's Encrypt install
echo "------------------------------------------------------------------------------"
read -p " Do you want to run Let's Encrypt? <Y/n>" prompt
echo "------------------------------------------------------------------------------"
if [ "$prompt" = "y" ]; then
    apt-get install -y certbot
    certbot certonly -m $EMAIL --agree-tos -n --force-renewal --authenticator standalone -d $DOMAIN -d www.$DOMAIN --pre-hook "service nginx stop" --post-hook "service nginx start"
fi

cat > /etc/nginx/sites-available/$DOMAIN.conf <<EOF
# $DOMAIN server configuration

server {
    listen      80;
    server_name $DOMAIN www.$DOMAIN;
    return      301 https://$DOMAIN$request_uri;
}

server {
    listen      443 ssl http2;
    server_name www.$DOMAIN $DOMAIN;
    root        /var/www/$DOMAIN;
    index       index.php index.html index.htm;

    # Uncomment to use Nginx as a Nodejs app proxy on port 8080.
    #location / {
    #   proxy_pass http://localhost:8080;
    #   proxy_http_version 1.1;
    #   proxy_set_header Upgrade $http_upgrade;
    #   proxy_set_header Connection 'upgrade';
    #   proxy_set_header Host $host;
    #   proxy_cache_bypass $http_upgrade;
    #}

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

    # Protocol
    ssl_protocols TLSv1.2 TLSv1.3; 

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

# Set right access to www folder
usermod -a -G www-data $USER
chown -R $USER:www-data /var/www
chgrp -R www-data /var/www
chmod -R g+rw /var/www
setfacl -d -R -m g::rw /var/www

# MariaDB install
echo "------------------------------------------------------------------------------"
read -p " Do you want to install MariaDB? <Y/n> " prompt
echo "------------------------------------------------------------------------------"
if [ "$prompt" = "y" ]; then
    apt-get install -y mariadb-server mariadb-client
    mysql_secure_installation
fi

# PhpMyAdmin install
#echo "------------------------------------------------------------------------------"
#read -p " Do you want to install phpMyAdmin? <Y/n> " prompt
#echo "------------------------------------------------------------------------------"
#echo
#if [ "$prompt" = "y" ]; then
#    apt-get install -y phpmyadmin
#    ln -s /usr/share/phpmyadmin /var/www/$DOMAIN
#fi


DEBIAN_FRONTEND=noninteractive apt-get -yq install phpmyadmin
ln -s /usr/share/phpmyadmin /var/www/$DOMAIN
mysql
SELECT user,authentication_string,plugin,host FROM mysql.user;
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$PASSWORD';
FLUSH PRIVILEGES;
SELECT user,authentication_string,plugin,host FROM mysql.user;
exit


# Wifi setup with usb dongle
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

# Fail2ban install
apt-get install -y fail2ban
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
# Edit jail local

# Install a firewall (may not be necessary)
#apt-get install -y ufw
#ufw enable

# Renew Let's Encrypt script (to be scripted)
crontab -e
30 3 * * 0 /opt/letsencrypt/letsencrypt-auto renew >> /var/log/letsencrypt/renewal.log

# Dhparam (take looong time on Raspberry pi)
#openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096

#Setting the DNS servers on your Raspberry Pi
#sudo nano /etc/dhcpcd.conf
#static domain_name_servers=8.8.4.4 8.8.8.8


#start ssh service
systemctl enable ssh
systemctl start ssh

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
read -p " Do you want to restart? <y/N> " prompt
if [ "$prompt" = "y" ]; then
    reboot
fi
