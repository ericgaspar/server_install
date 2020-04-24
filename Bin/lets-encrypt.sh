#!/bin/sh


if [ "$(whoami)" != "root" ]; then
    echo "Run script as ROOT!"
    exit
fi

# --Let's Encrypt install---------------------------------------------

read -r -p "Do you want to install Let's Encrypt? [Y/n] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
	read -p " Enter your Domain Name: " DOMAIN
	read -p " Enter your E-mail Adress: " EMAIL
    apt-get install -y certbot
    certbot certonly -m $EMAIL --agree-tos -n --force-renewal --authenticator standalone -d $DOMAIN -d www.$DOMAIN --pre-hook "service nginx stop" --post-hook "service nginx start"
else
    exit 0
fi