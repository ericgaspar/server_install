#!/bin/sh


if [ "$(whoami)" != "root" ]; then
    echo "Run script as ROOT!"
    exit
fi

# --NodeJS install----------------------------------------------------

read -r -p "Do you want to install NGNIX? [Y/n] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
	apt-get install -y nginx
else
    exit 0
fi


update-rc.d nginx defaults
sed -i 's/# server_names_hash_bucket_size/server_names_hash_bucket_size/' /etc/nginx/nginx.conf


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

echo " La version suivante de NGINX a été installée :"
echo " NGINX version:  `nginx -v`"

