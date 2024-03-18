#!/bin/bsah
#set -e
os_name=$(awk '{print $1}' /etc/redhat-release)
os_ver=$(awk '{print $4}' /etc/redhat-release|awk -F. '{print $1}')
groupadd zabbix && useradd -g zabbix zabbix
groupadd nginx && useradd -g nginx nginx
groupadd mysql && useradd -g mysql mysql
groupadd apache && useradd -g apache apache

echo -e "\033[33m \033[33m 1.检查离线的部署包是否存在，请确保相关的部署包已经放在/root根目录下\033[0m" && sleep 5

if [ -f '/root/zabbix5.0_LTS-os7-rpm.tar.gz' ];
then
    echo -e "\033[31m zabbix5.0_LTS-os7-rpm.tar.gz文件存在，可以继续！\033[0m" && sleep 5
    echo -e "\033[33m 2.检查环境，系统版本和防火墙和selinux的配置\033[0m" && sleep 5
   
    if [ $os_name = "CentOS" ] && [ $os_ver -eq 7 ];
    then
        echo -e "\033[31m 系统版本检查通过,可以继续,$os_name,$os_ver\033[0m" && sleep 5
		echo -e "\033[33m 3.防火墙和selinux的设置，防火墙先关闭后开启\033[0m" && sleep 5
		systemctl stop firewalld
		sed -i '7c\SELINUX=disabled' /etc/selinux/config
		setenforce 0
		echo -e "\033[33m 4.解压rpm离线包" && sleep 5
	
		if [ -d "/zabbix/" ];
		then
			echo -e "\033[32m /zabbix文件夹已存在，执行脚本将会覆盖原文件夹内容。\033[0m" 
			read -p "请输入y,按回车确认" rm_ok
		
			if [ $rm_ok = 'y' ];
			then
				rm -rf /zabbix
				mkdir -p /zabbix
				tar -xvf /root/zabbix5.0_LTS-os7-rpm.tar.gz -C /zabbix
				echo -e "\033[33m 文件已解压到/zabbix目录中\033[0m" && sleep 5
				echo -e "\033[33m 5.安装数据库\033[0m" && sleep 5
			
				if [ $(yum list installed |grep mariadb-server|wc -l) -eq 0 ];
				then
					cd /zabbix/zabbix5.0_LTS-os7-rpm/
					#
					rm -rf $(find / -name my.cnf)
					rm -rf $(find / -name mysql)
					yum remove $(yum list installed |grep mariadb) -y 
					yum remove $(yum list installed |grep mysql) -y
					rpm -ivh  r* au* c* f* g* lib* O* p* s* u* mariadb-lib* net* mariadb-server* mariadb-5* --nodeps --force
					echo -e "\033[33m \nmariadb 安装完成!\033[0m" && sleep 5
					systemctl start mariadb && echo -e "\033[33m \nmysql已启动\033[0m"
					echo -e "\033[31m 6.创建zabbix数据库\033[0m"
					read -p "请定义zabbix数据库zabbix用户的密码，按回车确认" zabbix_pwd && sleep 5
					mysql -e "create database zabbix character set utf8 collate utf8_bin;grant all privileges on zabbix.* to 'zabbix'@'localhost' identified by '$zabbix_pwd';flush privileges;"
					echo -e "\033[31m 7.安装zabbix和nginx,默认覆盖安装\033[0m" && sleep 5
					yum remove $(yum list installed|grep zabbix) -y
					yum remove $(yum list installed|grep nginx) -y
					rm -rf $(find / -name nginx)
					cd /zabbix/zabbix5.0_LTS-os7-rpm/
					rpm -ivh  rh-* zabbix-nginx* zabbix-web* zabbix-agent* zabbix-server*  --nodeps --force
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
					echo -e "\033[31m 13.添加防火墙策略\033[0m"
					systemctl enable --now firewalld && sleep 5
					firewall-cmd --add-port={22,80,10050}/tcp --zone=public --permanent
					firewall-cmd --reload
					
					
				else
				  
					read -p "\n检测到已经安装过mysql数据库,是否卸载重装(y-确认卸载重装，n-保留旧版本) "  remove_mysql
				
					if [ $remove_mysql = 'y' ];
					then
						cd /zabbix/zabbix5.0_LTS-os7-rpm/
						#
						rm -rf $(find / -name my.cnf)
						rm -rf $(find / -name mysql)
						yum remove $(yum list installed |grep mariadb) -y 
						yum remove $(yum list installed |grep mysql) -y
						rpm -ivh  r* au* c* f* g* lib* O* p* s* u* mariadb-lib* net* mariadb-server* mariadb-5* --nodeps --force
						echo -e "\033[33m \nmariadb 安装完成!\033[0m" && sleep 5
						systemctl start mariadb
						echo -e "\033[33m \nmysql已启动\033[0m" && sleep 5
						echo -e "\033[31m 6.创建zabbix数据库\033[0m" && sleep 5
						read -p "请定义zabbix数据库zabbix用户的密码，按回车确认" zabbix_pwd
						mysql -e "create database zabbix character set utf8 collate utf8_bin;grant all privileges on zabbix.* to 'zabbix'@'localhost' identified by '$zabbix_pwd';flush privileges;"
						echo -e "\033[31m 7.安装zabbix和nginx,默认覆盖安装\033[0m" && sleep 5
						yum remove $(yum list installed|grep zabbix) -y
						yum remove $(yum list installed|grep nginx) -y
						rm -rf $(find / -name nginx)
						cd /zabbix/zabbix5.0_LTS-os7-rpm/
						rpm -ivh  rh-* zabbix-nginx* zabbix-web* zabbix-agent* zabbix-server*  --nodeps --force
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
					else
					
						if [ $remove_mysql = 'n' ];
						then
							echo -e "\033[33m \nmysql保留旧版本\033[0m" && sleep 5
							systemctl start mariadb
							echo -e "\033[33m \nmysql已启动\033[0m" && sleep 5
							echo -e "\033[33m 6.创建zabbix数据库\033[0m" && sleep 5
							read -p "请定义zabbix数据库zabbix用户的密码，按回车确认" zabbix_pwd
							read -p "请输入原数据库root用户的密码，按回车确认" mysql_root_pwd
							mysql -uroot -p$mysql_root_pwd -e "create database zabbix character set utf8 collate utf8_bin;grant all privileges on zabbix.* to 'zabbix'@'localhost' identified by '$zabbix_pwd';flush privileges;"
							echo -e "\033[33m 7.安装zabbix和nginx,默认覆盖安装\033[0m" && sleep 5
							yum remove $(yum list installed|grep zabbix) -y
							yum remove $(yum list installed|grep nginx) -y
							rm -rf $(find / -name nginx)
							cd /zabbix/zabbix5.0_LTS-os7-rpm/
							rpm -ivh  rh-* zabbix-nginx* zabbix-web* zabbix-agent* zabbix-server*  --nodeps --force
							echo -e "\033[33m zabbix和nginx已完成安装！\033[0m" && sleep 5
							echo -e "\033[33m 8.zabbix数据库的导入\033[0m" && sleep 5
							zcat /usr/share/doc/zabbix-server-mysql-5.0.17/create.sql.gz |mysql -uzabbix -p$zabbix_pwd zabbix
							echo -e "\033[33m 9.zabbix配置文件的修改\033[0m" && sleep 5
							sed -i "/# DBPassword=/aDBPassword=$zabbix_pwd" /etc/zabbix/zabbix_server.conf
							echo -e "\033[33m 10.nginx配置文件的修改\033[0m" && sleep 5
							sed -i '38,117s/^/#/' /etc/opt/rh/rh-nginx116/nginx/nginx.conf
							sed -i '2,3s/^#//' /etc/opt/rh/rh-nginx116/nginx/conf.d/zabbix.conf
							sed -i 's/example.com/localhost/g' /etc/opt/rh/rh-nginx116/nginx/conf.d/zabbix.conf
							echo -e "\033[33m 11.php配置文件的修改\033[0m" && sleep 5
							sed -i '24c\php_value[date.timezone] = Asia/Shanghai' /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
							sed -i '6c\listen.acl_users = apache,nginx' /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
							echo -e "\033[33m 12.启动所有服务\033[0m" && sleep 5
							systemctl restart zabbix-server zabbix-agent rh-nginx116-nginx rh-php72-php-fpm mariadb
							systemctl enable zabbix-server zabbix-agent rh-nginx116-nginx rh-php72-php-fpm  mariadb
							read -p "定义主机名：" set_hostname
							hostnamectl set-hostname $set_hostname
							echo -e "\033[33m 13.添加防火墙策略\033[0m" && sleep 5
							systemctl enable --now firewalld
							firewall-cmd --add-port={22,80,10050}/tcp --zone=public --permanent
							firewall-cmd --reload
						fi
					fi
				fi	  
			elif [ $rm_ok = 'n' ];
			then
				echo -e "\033[33m 文件夹创建出现异常,已经停止后续的步骤.\033[0m" && sleep 5
			fi
		else
			mkdir -p /zabbix
			tar -xvf /root/zabbix5.0_LTS-os7-rpm.tar.gz -C /zabbix
			echo -e "\033[33m 文件已解压到/zabbix目录中\033[0m" && sleep 5
			echo -e "\033[33m 5.安装数据库\033[0m" && sleep 5
				
				if [ $(yum list installed |grep mariadb-server|wc -l) -eq 0 ];
				then
					cd /zabbix/zabbix5.0_LTS-os7-rpm/
					#
					rm -rf $(find / -name my.cnf)
					rm -rf $(find / -name mysql)
					yum remove $(yum list installed |grep mariadb) -y 
					yum remove $(yum list installed |grep mysql) -y
					rpm -ivh  r* au* c* f* g* lib* O* p* s* u* mariadb-lib* net* mariadb-server* mariadb-5* --nodeps --force
					echo -e "\033[33m \nmariadb 安装完成!\033[0m" && sleep 5
					systemctl start mariadb
					echo -e "\033[33m \nmysql已启动\033[0m" && sleep 5
					echo -e "\033[31m 6.创建zabbix数据库\033[0m" && sleep 5
					read -p "请定义zabbix数据库zabbix用户的密码，按回车确认" zabbix_pwd
					mysql -e "create database zabbix character set utf8 collate utf8_bin;grant all privileges on zabbix.* to 'zabbix'@'localhost' identified by '$zabbix_pwd';flush privileges;"
					echo -e "\033[31m 7.安装zabbix和nginx,默认覆盖安装\033[0m" && sleep 5
					yum remove $(yum list installed|grep zabbix) -y
					yum remove $(yum list installed|grep nginx) -y
					rm -rf $(find / -name nginx)
					cd /zabbix/zabbix5.0_LTS-os7-rpm/
					rpm -ivh  rh-* zabbix-nginx* zabbix-web* zabbix-agent* zabbix-server*  --nodeps --force
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
					reboot
				else
					read -p "检测到已经安装过mysql数据库,是否卸载重装(y-确认卸载重装，n-保留旧版本) "  remove_mysql
					if [ $remove_mysql = 'y' ];
					then
						cd /zabbix/zabbix5.0_LTS-os7-rpm/
						#
						rm -rf $(find / -name my.cnf)
						rm -rf $(find / -name mysql)
						yum remove $(yum list installed |grep mariadb) -y 
						yum remove $(yum list installed |grep mysql) -y
						rpm -ivh  r* au* c* f* g* lib* O* p* s* u* mariadb-lib* net* mariadb-server* mariadb-5* --nodeps --force
						echo -e "\033[33m \nmariadb 安装完成!\033[0m" && sleep 5
						systemctl start mariadb
						echo -e "\033[33m \nmysql已启动\033[0m" && sleep 5
						echo -e "\033[31m 6.创建zabbix数据库\033[0m" && sleep 5
						read -p "请定义zabbix数据库zabbix用户的密码，按回车确认" zabbix_pwd
						mysql -e "create database zabbix character set utf8 collate utf8_bin;grant all privileges on zabbix.* to 'zabbix'@'localhost' identified by '$zabbix_pwd';flush privileges;"
						echo -e "\033[31m 7.安装zabbix和nginx,默认覆盖安装\033[0m" && sleep 5
						yum remove $(yum list installed|grep zabbix) -y
						yum remove $(yum list installed|grep nginx) -y
						rm -rf $(find / -name nginx)
						cd /zabbix/zabbix5.0_LTS-os7-rpm/
						rpm -ivh  rh-* zabbix-nginx* zabbix-web* zabbix-agent* zabbix-server*  --nodeps --force
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
					else
						if [ $remove_mysql = 'n' ];
						then
							echo -e "\033[33m \nmysql保留旧版本\033[0m" && sleep 5
							systemctl start mariadb
							echo -e "\033[33m \nmysql已启动\033[0m" && sleep 5
							echo -e "\031[33m 6.创建zabbix数据库\033[0m" && sleep 5
							read -p "请定义zabbix数据库zabbix用户的密码，按回车确认" zabbix_pwd
							read -p "请输入原数据库root用户的密码，按回车确认" mysql_root_pwd
							mysql -uroot -p$mysql_root_pwd -e "create database zabbix character set utf8 collate utf8_bin;grant all privileges on zabbix.* to 'zabbix'@'localhost' identified by '$zabbix_pwd';flush privileges;"
							echo -e "\033[31m 7.安装zabbix和nginx,默认覆盖安装\033[0m" && sleep 5
							yum remove $(yum list installed|grep zabbix) -y
							yum remove $(yum list installed|grep nginx) -y
							rm -rf $(find / -name nginx)
							cd /zabbix/zabbix5.0_LTS-os7-rpm/
							rpm -ivh rh-* zabbix-nginx* zabbix-web* zabbix-agent* zabbix-server*  --nodeps --force
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
							reboot
						fi
					fi
				fi	  	
		fi
	else
		echo -e "\033[33m 无法匹配系统版本\033[0m" && sleep 5
	fi
else
   echo -e "\033[33m zabbix5.0_LTS-os7-rpm.tar.gz文件不存在,请先上传包!\033[0m" && sleep 5
fi


