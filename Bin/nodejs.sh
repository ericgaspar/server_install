#!/bin/sh


if [ "$(whoami)" != "root" ]; then
    echo "Run script as ROOT!"
    exit
fi

# --NodeJS install----------------------------------------------------

read -r -p "Do you want to install Nodejs? [Y/n] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
	read -p " Enter the Nodejs version you want to install: " VERSION
    curl -sL https://deb.nodesource.com/setup_$VERSION | sudo bash -
	apt-get install -y nodejs
else
    exit 0
fi

echo " Les version suivantes on été installées :"
echo " Nodejs version:  `node -v`"
echo " npm version:     `npm -v`"