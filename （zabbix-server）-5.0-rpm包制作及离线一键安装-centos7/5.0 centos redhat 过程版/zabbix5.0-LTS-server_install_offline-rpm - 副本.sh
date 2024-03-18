#!/bin/bsah
os_name=$(awk '{print $1}' /etc/redhat-release)
os_ver=$(awk '{print $4}' /etc/redhat-release|awk -F. '{print $1}')
echo "1.检查离线的部署包是否存在，请确保相关的部署包已经放在/root根目录下"

if [ -f '/root/zabbix5.0_LTS-os7-rpm.tar.gz' ];
then
    echo "zabbix5.0_LTS-os7-rpm.tar.gz文件存在，可以继续！"
    echo "2.检查环境，系统版本和防火墙和selinux的配置"
   
    if [ $os_name = "CentOS" ] && [ $os_ver -eq 7 ];
    then
        echo "系统版本检查通过,可以继续,$os_name,$os_ver"
		echo "3.防火墙和selinux的设置，防火墙先关闭后开启"
		systemctl stop firewalld
		sed -i '7c\SELINUX=disabled' /etc/selinux/config
		echo "4.解压rpm离线包"
	
		if [ -d "/zabbix/" ];
		then
			echo "/zabbix文件夹已存在是否先清空内容，输入y确认清空，输入n将停止后续的步骤"
			read -p "请输入y/n,按回车确认" -s rm_ok
		
			if [ $rm_ok = 'y' ];
			then
				rm -rf /zabbix
				mkdir -p /zabbix
				tar -xvf /root/zabbix5.0_LTS-os7-rpm.tar.gz -C /zabbix
				echo "文件已解压到/zabbix目录中"
				echo "5.安装数据库"
			
				if [ $(yum list installed |grep mariadb-server|wc -l) -eq 0 ];
				then
					cd /zabbix/zabbix5.0_LTS-os7-rpm/
					groupadd mysql && useradd -g mysql mysql
					rm -rf $(find / -name my.cnf)
					rm -rf $(find / -name mysql)
					yum remove $(yum list installed |grep mariadb) -y
					rpm -ivh  r* au* c* f* g* lib* O* p* s* u* mariadb-lib* net* mariadb-server* mariadb-5* --nodeps --force
					echo "\nmariadb 安装完成!"
					systemctl start mariadb && echo "\nmysql已启动"
				else
				    echo $(yum list installed |grep mariadb-server|wc -l)
					read -p "\n检测到已经安装过mysql数据库,是否卸载重装(y-确认卸载重装，n-保留旧版本) " -s remove_mysql
				
					if [ $remove_mysql = 'y' ];
					then
						cd /zabbix/zabbix5.0_LTS-os7-rpm/
						groupadd mysql && useradd -g mysql mysql
						rm -rf $(find / -name my.cnf)
						rm -rf $(find / -name mysql)
						yum remove $(yum list installed |grep mariadb) -y
						rpm -ivh  r* au* c* f* g* lib* O* p* s* u* mariadb-lib* net* mariadb-server* mariadb-5* --nodeps --force
						echo "\nmariadb 安装完成!"
						systemctl start mariadb
						echo "\nmysql已启动"
					else
					
						if [ $remove_mysql = 'n' ];
						then
							echo "\nmysql保留旧版本"
							systemctl start mariadb
							echo "\nmysql已启动"
						fi
					fi
				fi	  
			elif [ $rm_ok = 'n' ];
				echo "\n文件夹创建出现异常,已经停止后续的步骤."
			fi
		else
			mkdir -p /zabbix
			tar -xvf /root/zabbix5.0_LTS-os7-rpm.tar.gz -C /zabbix
			echo "文件已解压到/zabbix目录中"
			echo "5.安装数据库"
				
				if [ $(yum list installed |grep mariadb-server|wc -l) -eq 0 ];
				then
					cd /zabbix/zabbix5.0_LTS-os7-rpm/
					groupadd mysql && useradd -g mysql mysql
					rm -rf $(find / -name my.cnf)
					rm -rf $(find / -name mysql)
					yum remove $(yum list installed |grep mariadb) -y
					echo "\nmariadb 安装完成!"
					systemctl start mariadb && echo "\nmysql已启动"
				else
					read "\n检测到已经安装过mysql数据库,是否卸载重装(y-确认卸载重装，n-保留旧版本) " -s remove_mysql
					if [ $remove_mysql = 'y' ];
					then
						cd /zabbix/zabbix5.0_LTS-os7-rpm/
						groupadd mysql && useradd -g mysql mysql
						rm -rf $(find / -name my.cnf)
						rm -rf $(find / -name mysql)
						yum remove $(yum list installed |grep mariadb) -y
						rpm -ivh  r* au* c* f* g* lib* O* p* s* u* mariadb-lib* net* mariadb-server* mariadb-5* --nodeps --force 
						echo "\nmariadb 安装完成!"
						systemctl start mariadb
						echo "\nmysql已启动"
					else
						if [ $remove_mysql = 'n' ];
						then
							echo "\nmysql保留旧版本"
							systemctl start mariadb
							echo "\nmysql已启动"
						fi
					fi
				fi	  	
		fi
	else
		echo "无法匹配系统版本"
	fi
else
   echo "zabbix5.0_LTS-os7-rpm.tar.gz文件不存在,请先上传包!"
fi


