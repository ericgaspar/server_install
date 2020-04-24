#!/bin/sh


if [ "$(whoami)" != "root" ]; then
    echo "Run script as ROOT!"
    exit
fi

# --PHP install-------------------------------------------------------