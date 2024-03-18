#!/bin/bash
clear
echo -e "\033[33m--------------------------zabbix4.0-server-安装条件-------------------
安装zabbix4.0-server标准版;(4.0-lts)
适用版本：内核2.6、3.0 测试正常
只支持处理器x86_64
linux OS版本6、7、8
Creator:
反馈：mail: pzl960504@163.com
------------------------------------------安装方法-----------------------
1.请先将做好的zabbix4.0_LTS-os$OS-rpm.tar.gz上传到此服务器的/root下
2.运行脚本sh zabbix4.0-LTS-server_install_offline(rpm).sh
3.根据提示输入以下信息，按回车进行下一步
—
===========================-请按提示输入以下信息-============================
\033[0m
"
sleep 5
echo -e "\033[31m【0】请选项你的OS版本(6或者7或者8)并按回车确认：\033[0m"
read OS
echo -e "\033[31m【1】请定义数据库zabbix用户的密码并按回车键确认：\033[0m"
read zabbix_pwd
echo -e "\033[31m【2】请定义web服务web的端口(不建议80)并按回车确认：\033[0m"
read apache_port
echo -e "\033[31m【3】请定义主机名并按回车键确认：\033[0m"
read set_hostname
echo '即将开始自动安装'
clear
echo "第一步:关闭selinux和防火墙"
systemctl stop firewalld && systemctl disable firewalld
sed -i 's\enforcing\disabled\g' /etc/selinux/config
setenforce 0
echo "第二步:将rpm压缩包解压"
tar zxvf /root/zabbix4.0_LTS-os"$OS"-rpm.tar.gz
cd zabbix4.0_LTS-os"$OS"-rpm
echo "第三步：创建相关的用户，并依次安装相关服务"
groupadd zabbix && useradd -g zabbix zabbix
groupadd nginx && useradd -g nginx nginx
groupadd mysql && useradd -g mysql mysql
groupadd apache && useradd -g apache apache
rpm -ivh  a* c* d* f* g* j* lib* O* p*  u* m* n* h*  --nodeps --force
rpm -ivh  zabbix-web* zabbix-agent* zabbix-server*  --nodeps --force
echo "第四步：启动数据库，并导入初始数据"
systemctl start mariadb
sed -i '/pid-file=/ainnodb_strict_mode=0\n' /etc/my.cnf.d/mariadb-server.cnf
systemctl restart mariadb
mysql -e "create database zabbix character set utf8 collate utf8_bin;grant all privileges on zabbix.* to 'zabbix'@'localhost' identified by '$zabbix_pwd';flush privileges;"
zcat /usr/share/doc/zabbix-server-mysql/create.sql.gz |mysql -uzabbix -p$zabbix_pwd zabbix
echo '第五步：修改配置文件,【时区,web用户、zabbix-server配置、nginx配置文件'
sed -i '/# DBPassword=/aDBPassword='$zabbix_pwd'' /etc/zabbix/zabbix_server.conf
sed -i '$ a\EnableRemoteCommands=1' /etc/zabbix/zabbix_agentd.conf
#sed -i '38,117s/^/#/' /etc/opt/rh/rh-nginx116/nginx/nginx.conf
#sed -i '/server {/a\        listen          '$nginx_port';\n        server_name     localhost;' /etc/opt/rh/rh-nginx116/nginx/conf.d/zabbix.conf
sed -i '$ a\php_value[date.timezone] = Asia/Shanghai' /etc/php-fpm.d/zabbix.conf
sed -i 's\80\'$apache_port'\g' /etc/httpd/conf/httpd.conf
#sed -i '6c\listen.acl_users = apache,nginx' /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
echo '第六步：启动服务,更改主机名'
systemctl restart zabbix-server zabbix-agent httpd php-fpm  mariadb
systemctl enable zabbix-server zabbix-agent httpd php-fpm mariadb
hostnamectl set-hostname $set_hostname
clear
echo '第七步：开启防火墙，放行相关端口。'
sleep 10
systemctl start firewalld
firewall-cmd --add-port=10050/tcp --zone=public --permanent
firewall-cmd --add-port=10051/tcp --zone=public --permanent
firewall-cmd --add-port=$apache_port/tcp --zone=public --permanent
firewall-cmd --add-port=3306/tcp --zone=public --permanent
firewall-cmd --reload
clear
sleep 6
echo -e "\033[32m
-------------------------安装完成，zabbix-server系统信息如下----------------------------------
-
-
-
-
0.默认防火墙处于enable的状态
1.端口 zabbix-server 10051 agent 10050 mysql 3306 apache $apache_port php 9000
2.访问 http://$(hostname -i|grep -oP "\K([0-9]{1,3}[.]){3}[0-9]{1,3}"):$apache_port/zabbix
3.数据库密码为$zabbix_pwd
4.web账号Admin 密码zabbix
5.服务启动|停止|重启的方法:
systemctl enable|start|restart|stop  zabbix-server zabbix-agent rh-nginx116-nginx rh-php72-php-fpm  mariadb
6.server版本信息：
$(/usr/sbin/zabbix_server -V|head -1)
-
=========================================开始在web端进行配置=====================




url: http://$(hostname -i|grep -oP "\K([0-9]{1,3}[.]){3}[0-9]{1,3}"):$apache_port/zabbix
-
-
-
-
\033[0m
"
for time in {10..0}
do
  sleep 1
  echo 系统将在”$time“秒以后重启
done
echo '第六步，系统正在重启'
reboot
