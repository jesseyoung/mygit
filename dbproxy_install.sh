#!/bin/bash

#Company by Shanghai Action
#Author by Renzhongyu
#Create Date by 2017-02-16
#Modify Date by 2017-03-14

APP_DIR=/opt/actionisky_proxy
JDK_DIR='jdk1.7.0_45'
DBP_DIR='dbproxy_2.2.7'
JDK='/opt/jdk-7u45-linux-x64.tar.gz'
DBP='/opt/dbproxy_2.2.7.zip'
DBPI='/opt/dbproxy'
ROUTER='/opt/router.xml'

M_USER=$1
M_PASS=$2
M_IP=$3
M_PORT=$4

S_USER=$5
S_PASS=$6
S_IP=$7
S_PORT=$8

DBP_USER=$9
DBP_PASS=${10}


Download(){
echo 'Begin download package for dbproxy...'
if [ ! -d "/opt" ];then
	mkdir /opt
fi

curl -0Lo /opt/dbproxy_2.2.7.zip https://seafile.actionsky.com/f/307767e147/?raw=1
curl -0Lo /opt/router.xml https://seafile.actionsky.com/f/48dcabeafa/?raw=1
curl -0Lo /opt/jdk-7u45-linux-x64.tar.gz https://seafile.actionsky.com/f/d4b93a8635/?raw=1
curl -0Lo /opt/dbproxy https://seafile.actionsky.com/f/898d616f13/?raw=1
}

Install(){
echo 'Begin Install ...'
if [ -d "$APP_DIR" ];then
	rm -rf /opt/action_proxy
	mkdir -p $APP_DIR
else
	mkdir -p $APP_DIR
fi

echo 'Install Java Environment...'
rpm -e `rpm -qa | grep jdk` 2> /dev/null
tar xfz $JDK -C $APP_DIR
ln -s $APP_DIR/$JDK_DIR/bin/java /usr/bin/ 

echo 'Install MySQL meta database for DBproxy...'
yum install -y mysql-server mysql mysql-devel 1>/dev/null
chkconfig --level 2345  mysqld on
/etc/init.d/mysqld start 1>/dev/null

echo 'Install DBproxy...'
unzip $DBP -d $APP_DIR 1>/dev/null

echo 'Finish install...'
}

Configure(){
echo 'Begin to Config DBproxy...'
cp $APP_DIR/$DBP_DIR/target/etc/conf.properties $APP_DIR/$DBP_DIR/target/etc/conf.properties.bak
sed -i "s/\(mysql:\/\/\).*\(\/paralleldb\)/\1127.0.0.1:3306\2/" $APP_DIR/$DBP_DIR/target/etc/conf.properties
sed -i "s/db.username=admin/db.username=root/" $APP_DIR/$DBP_DIR/target/etc/conf.properties
sed -i "s/db.password=admin/db.password=/" $APP_DIR/$DBP_DIR/target/etc/conf.properties

mv $APP_DIR/$DBP_DIR/target/etc/router.xml $APP_DIR/$DBP_DIR/target/etc/router.xml.bak
sed -i "s/mysql_user1/$M_USER/" $ROUTER
sed -i "s/mysql_passwd1/$M_PASS/" $ROUTER
sed -i "s/mysql_host1/$M_IP/" $ROUTER
sed -i "s/mysql_port1/$M_PORT/" $ROUTER

sed -i "s/mysql_user2/$S_USER/" $ROUTER
sed -i "s/mysql_passwd2/$S_PASS/" $ROUTER
sed -i "s/mysql_host2/$S_IP/" $ROUTER
sed -i "s/mysql_port2/$S_PORT/" $ROUTER

sed -i "s/proxy_user/$DBP_USER/" $ROUTER
sed -i "s/proxy_passwd/$DBP_PASS/" $ROUTER
cp $ROUTER $APP_DIR/$DBP_DIR/target/etc/
}

Starting(){
echo 'Begin staring dbproxy...'
chmod +x $APP_DIR/$DBP_DIR/target/run_proxy.sh 
chmod +x $APP_DIR/$DBP_DIR/target/shutdown.sh
sed -i "s%DIR=.*%DIR=$APP_DIR/$DBP_DIR/target%" $DBPI
cp $DBPI /etc/init.d/
chmod +x /etc/init.d/dbproxy
chkconfig --level 2345 dbproxy on
/etc/init.d/dbproxy start
}

Routing(){
echo 'Persist router information to meta database...'
mysql -uactionsky -pgold -h127.0.0.1 -P8808 -e "route @@add;"
#mysql -uactionsky -pgold -h127.0.0.1 -P8808 -e "route @@commit;"
echo 'Persist finished...'
echo 'Install complete.'
}

Removing(){
echo 'Clean install package.'
rm -f $DBP
rm -f $JDK
rm -f $ROUTER
rm -f $DBPI
}

if [ $# -lt 6 ];then
	echo "You must entry 6 parameter at least."
	echo "eg. ./dbproxy_install.sh master_user master_password master_ip master_port slave_user slave_passwod slave_ip slave_port dbp_user dbp_password"
	exit 1
fi

echo $@

Download
Install
Configure
Starting
Routing
Removing

