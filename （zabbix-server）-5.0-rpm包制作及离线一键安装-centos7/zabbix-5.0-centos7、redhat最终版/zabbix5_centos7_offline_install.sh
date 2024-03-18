#!/bin/bsah
#set -e
#@author pzl960504@163.com
#脚本说明：适用于在centos7上离线安装zabbix5.0LTS,脚本和rpm包配合使用。rpm压缩包一定要放在/目录下
clear
echo -e "脚本使用说明：\n适用于在centos7上配合离线rpm包（zabbix5.0_LTS-os7-rpm.tar.gz）LNMP安装zabbix5.0\n如果机器上有mysql和nginx环境请先做好数据备份卸载干净再继续" 

echo -e "\033[32m 10秒后开始自动安装，请等待！" && sleep 10
os_name=$(awk '{print $1}' /etc/redhat-release)
os_ver=$(awk '{print $4}' /etc/redhat-release|awk -F. '{print $1}')

groupadd zabbix && useradd -g zabbix zabbix && sleep 2
groupadd nginx && useradd -g nginx nginx && sleep 2
groupadd mysql && useradd -g mysql mysql && sleep 2
groupadd apache && useradd -g apache apache && sleep 2

echo -e "\033[33m 1.检查离线的部署包是否存在，请确保相关的部署包已经放在/root根目录下\033[0m" && sleep 5
if [ -f '/root/zabbix5.0_LTS-os7-rpm.tar.gz' ];
then
    echo -e "\033[31m zabbix5.0_LTS-os7-rpm.tar.gz文件存在，5秒后自动继续！\033[0m" && sleep 5
    echo -e "\033[33m 2.检查环境，系统版本和防火墙和selinux的配置\033[0m" && sleep 5
   
    if [ $os_name = "CentOS" ] && [ $os_ver -eq 7 ];
    then
        echo -e "\033[31m 系统版本检查通过,可以继续,$os_name,$os_ver\033[0m" && sleep 5
		echo -e "\033[33m 3.防火墙和selinux的设置，防火墙先关闭后开启\033[0m" && sleep 5
		systemctl stop firewalld
		sed -i '7c\SELINUX=disabled' /etc/selinux/config
		setenforce 0
		echo -e "\033[33m 4.解压rpm离线包" && sleep 5
		mkdir -p /zabbix
		tar -xvf /root/zabbix5.0_LTS-os7-rpm.tar.gz -C /zabbix
		echo -e "5.安装数据库"
		cd /zabbix/zabbix5.0_LTS-os7-rpm/
		rm -rf $(find / -name my.cnf)
		rm -rf $(find / -name mysql)
		yum remove mariadb -y 
		yum remove mysql -y
		rpm -ivh  r* au* c* f* g* lib* O* p* s* u* mariadb-lib* net* mariadb-server* mariadb-5* --nodeps --force
		echo -e "\033[33m \nmariadb 安装完成!\033[0m" && sleep 5
		systemctl start mariadb
		echo -e "\033[31m mysql已启动\033[0m" && sleep 5
		echo -e "\033[33m 6.创建zabbix数据库\033[0m" && sleep 5
		read -p "请定义zabbix数据库zabbix用户的密码，按回车确认" zabbix_pwd
		mysql -e "create database zabbix character set utf8 collate utf8_bin;grant all privileges on zabbix.* to 'zabbix'@'localhost' identified by '$zabbix_pwd';flush privileges;"
		echo -e "\033[31m 7.安装zabbix和nginx,默认覆盖安装\033[0m" && sleep 5
		yum remove zabbix -y
		yum remove nginx -y
		cd /zabbix/zabbix5.0_LTS-os7-rpm/
		rpm -ivh  rh-* zabbix-nginx* zabbix-web* zabbix-agent* zabbix-server*  --nodeps --force
		rpm -ivh lib* t* php-* --nodeps --force
		echo -e "\033[33m zabbix和nginx已完成安装！\033[0m" && sleep 5
		echo -e "\033[31m 8.zabbix数据库的导入\033[0m" && sleep 5
		zcat /usr/share/doc/zabbix-server-mysql-5.0.17/create.sql.gz |mysql -uzabbix -p$zabbix_pwd zabbix
		echo -e "\033[31m 9.zabbix配置文件的修改\033[0m" && sleep 5
		sed -i "/# DBPassword=/aDBPassword=$zabbix_pwd" /etc/zabbix/zabbix_server.conf
		echo -e "\033[31m 10.nginx配置文件的修改\033[0m" && sleep 5
		sed -i '38,117s/^/#/' /etc/opt/rh/rh-nginx116/nginx/nginx.conf
		sed -i '2,3s/^#//' /etc/opt/rh/rh-nginx116/nginx/conf.d/zabbix.conf
		sed -i 's/example.com/localhost/g' /etc/opt/rh/rh-nginx116/nginx/conf.d/zabbix.conf
		echo -e "\033[31m 11.php配置文件的修改\033[0m" && sleep 5
		sed -i '24c\php_value[date.timezone] = Asia/Shanghai' /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
		sed -i '6c\listen.acl_users = apache,nginx' /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
		echo -e "\033[31m 12.启动所有服务\033[0m" && sleep 5
		systemctl restart zabbix-server zabbix-agent rh-nginx116-nginx rh-php72-php-fpm mariadb
		systemctl enable zabbix-server zabbix-agent rh-nginx116-nginx rh-php72-php-fpm  mariadb
		read -p "定义主机名：" set_hostname
		hostnamectl set-hostname $set_hostname
		echo -e "\033[31m 13.添加防火墙策略\033[0m" && sleep 5
		systemctl enable --now firewalld
		firewall-cmd --add-port={22,80,10050}/tcp --zone=public --permanent
		firewall-cmd --reload
		mysql -e "grant all privileges on *.* to root@localhost identified by 'passwd123';"
		echo -e "\033[32m
		-------------------------安装完成，zabbix-server系统信息如下----------------------------------
		
		0.默认防火墙处于enable的状态
		1.端口 zabbix-server 10051 agent 10050 mysql 3306 nginx $nginx_port php 9000
		2.访问 http://$(hostname -i|grep -oP "\K([0-9]{1,3}[.]){3}[0-9]{1,3}")
		3.zabbix数据库zabbix用户密码为$zabbix_pwd，root密码passwd123
		4.web账号Admin 密码$zabbix_pwd
		5.服务启动|停止|重启的方法:
		systemctl enable|start|restart|stop  zabbix-server zabbix-agent rh-nginx116-nginx rh-php72-php-fpm  mariadb
		6.server版本信息：
		$(/usr/sbin/zabbix_server -V|head -1)
		-
		=========================================开始在web端进行配置=====================
		url: http://$(hostname -i|grep -oP "\K([0-9]{1,3}[.]){3}[0-9]{1,3}")
		-
		-
		\033[0m
		"
                rm -rf /root/zabbix5.0_LTS-os7-rpm.tar.gz
                rm -rf /zabbix/zabbix5.0_LTS-os7-rpm
                history -c
                rm -rf /root/zabbix5_centos7_offline_install.sh
		
	else 
	    echo "系统版本匹配错误"
		exit 1
	fi
else
	echo "请先将离线包上传到服务器后继续"
	exit 1

fi
