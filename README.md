# Raspberry Pi LEMP server install script

## Installation

`wget https://raw.githubusercontent.com/ericgaspar/server_install/master/install.sh`

`sudo bash install.sh`

## Mysql
To connect to mysql

```
sudo mysql -u root -p

mysql> USE mysql;
mysql> SELECT User, Host, plugin FROM mysql.user;

+------------------+-----------------------+
| User             | plugin                |
+------------------+-----------------------+
| root             | UNIX_socket           |
| mysql.sys        | mysql_native_password |
| debian-sys-maint | mysql_native_password |
+------------------+-----------------------+


mysql> USE mysql;
mysql> UPDATE user SET plugin='mysql_native_password' WHERE User='root';
mysql> FLUSH PRIVILEGES;
mysql> exit;

$ service mysql restart

```

## Nodejs

```
npm install
```