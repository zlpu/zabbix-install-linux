#!/bin/bsah
#set -e
#@author 微信公众号：IT仔的笔记本
clear
cd /root
echo -e "脚本使用说明：\n
作者：微信公众号：IT仔的笔记本 \n
操作系统：ubuntu18-22.* x86 \n
最低配置：2c(CPU) 4GB(内存) 50GB(存储)
离线包：zabbix-server6.0-offlineinstall-ubuntu22.04-apt-packages.tar.gz \n
重点：请将离线包上传到/root目录下\n
如果机器上有mysql和nginx环境请先做好数据备份卸载干净再继续\n
整个过程耗时3分钟左右\n
有任何问题请留言微信公众号【IT仔的笔记本】" 
sleep 20
echo -e "\033[32m 10秒后开始自动安装，请等待！" && sleep 10
echo -e "\033[33m 检查离线的部署包是否存在，请确保相关的部署包已经放在/root根目录下\033[0m" && sleep 5
if [ -f '/root/zabbix-server6.0-offlineinstall-ubuntu22.04-apt-packages.tar.gz' ];
then 
	sudo tar -zxvf  zabbix-server6.0-offlineinstall-ubuntu22.04-apt-packages.tar.gz -C /opt
	# 写入本地源，如有需要，提取备份原有源
	echo "deb [trusted=yes] file:///opt/offline-packages  archives/"| sudo tee /etc/apt/sources.list 
	#deb [trusted=yes] file:///opt/offline-apt-packages archives/
	#更新源
	sudo apt-get update
	echo -e "1.安装数据库"
	apt remove mariadb* -y 
	apt remove mysql* -y
	apt install mariadb-server -y
	echo -e "\033[33m \nmariadb 安装完成!\033[0m" && sleep 5
	systemctl enable --now  mariadb
	echo -e "\033[31m mysql已启动\033[0m" && sleep 5
	echo -e "\033[33m 2.创建zabbix数据库\033[0m" && sleep 5
	#read -p "请定义zabbix数据库zabbix用户的密码，按回车确认" zabbix
	mysql -e "create database zabbix character set utf8mb4 collate utf8mb4_bin;"
	mysql -e "create user zabbix@localhost identified by 'zabbix';"
	mysql -e "grant all privileges on zabbix.* to zabbix@localhost;"
	mysql -e "set global log_bin_trust_function_creators = 1;"
	echo -e "\033[31m 3.安装zabbix和nginx,默认覆盖安装\033[0m" && sleep 5
	apt remove zabbix -y
	apt remove nginx -y
	apt install zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent -y
	echo -e "\033[33m zabbix和nginx已完成安装！\033[0m" && sleep 5
	echo -e "\033[31m 4.zabbix数据库的导入\033[0m" && sleep 5
	zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -pzabbix zabbix
	sleep 20
	mysql -e "set global log_bin_trust_function_creators = 0;"
	echo -e "\033[31m 5.zabbix配置文件的修改\033[0m" && sleep 5
	sed -i "/# DBPassword=/aDBPassword=zabbix" /etc/zabbix/zabbix_server.conf
	echo -e "\033[31m 6.nginx配置文件的修改\033[0m" && sleep 5
	sed -i '21,71s/^/#/' /etc/nginx/sites-enabled/default
	sed -i '2,3s/^#//' /etc/zabbix/nginx.conf
	sed -i 's/8080/80/g'  /etc/zabbix/nginx.conf
	sed -i 's/example.com/localhost/g'  /etc/zabbix/nginx.conf
	echo -e "\033[31m 7.启动所有服务\033[0m" && sleep 5
	systemctl restart zabbix-server zabbix-agent nginx php8.1-fpm mariadb
	systemctl enable zabbix-server zabbix-agent nginx php8.1-fpm mariadb
	echo -e "\033[31m 8.添加防火墙策略\033[0m" && sleep 5
	sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
	sudo iptables -A INPUT -p tcp --dport 10050 -j ACCEPT
	sudo iptables -A INPUT -p tcp --dport 10051 -j ACCEPT
	sudo iptables -A INPUT -p tcp --dport 10052 -j ACCEPT
	sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
	sudo iptables-save > /etc/iptables.rules
    touch /etc/network/if-pre-up.d/zabbix_iptables.sh
	chmod 777 /etc/network/if-pre-up.d/zabbix_iptables.sh
	cat >> /etc/network/if-pre-up.d/zabbix_iptables.sh <<EOF
	#!/bin/bash
	iptables-restore < /etc/iptables.rules
EOF
	
	mysql -e "grant all privileges on *.* to root@localhost identified by 'passwd123';"
	echo -e "\033[32m
	-------------------------安装完成，zabbix-server系统信息如下----------------------------------
	
	0.默认防火墙处于enable的状态
	1.端口 zabbix-server 10051 agent 10050 mysql 3306 nginx 80
	2.访问 http://$(hostname -I|grep -oP "\K([0-9]{1,3}[.]){3}[0-9]{1,3}")
	3.zabbix数据库zabbix用户密码为zabbix，root密码passwd123
	4.web账号Admin 密码zabbix
	5.服务启动|停止|重启的方法:
	systemctl enable|start|restart|stop  zabbix-server zabbix-agent nginx php8.1-fpm mariadb
	6.server版本信息：
	$(/usr/sbin/zabbix_server -V|head -1)
	-
	=========================================开始在web端进行配置=====================
	url: http://$(hostname -I|grep -oP "\K([0-9]{1,3}[.]){3}[0-9]{1,3}")
	- 配置数据库主机：localhost 数据库名称：zabbix密码：zabbix
	- web账号Admin 
	- web密码zabbix
	\033[0m
	"
	rm -rf /root/zabbix*
	history -c
		
else
	echo "请先将离线包上传到服务器后继续,获取离线包请联系微信公众号【IT仔的笔记本】"
	exit 1

fi
