read -p " Enter your Domain Name: " DOMAIN

apt-get update -y
apt-get upgrade -y

apt-get install nginx-full certbot -y
certbot certonly --authenticator standalone -d $DOMAIN -d www.$DOMAIN --pre-hook "service nginx stop" --post-hook "service nginx start"

cat > /etc/nginx/sites-enabled/$DOMAIN <<EOF
server {
	listen 80;
		server_name $DOMAIN www.$DOMAIN;

	location / {
		proxy_pass http://10.0.0.2:80;
  }
}

server {
	listen 443 ssl;
	server_name $DOMAIN www.$DOMAIN;

	root /var/www/$DOMAIN;
	index index.php index.html index.html;
  	
	ssl on;

	ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem; 
	ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
	ssl_session_timeout 1d;
	ssl_session_cache shared:SSL:50m;
	ssl_session_tickets off;
	ssl_protocols TLSv1.1 TLSv1.2;
	ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK';
	ssl_prefer_server_ciphers on;
	ssl_stapling on;
	ssl_stapling_verify on;
	ssl_trusted_certificate /etc/letsencrypt/live/$DOMAIN/chain.pem; 

	location / {
    	proxy_pass https://10.0.0.2:443;
  }
}
EOF

rm /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default

ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN

mv /var/www/html /var/www/$DOMAIN
rm /var/www/$DOMAIN/index.nginx-debian.html
echo "<p>It's working!"</p> > /var/www/$DOMAIN/index.html

nginx -t
service nginx restart

