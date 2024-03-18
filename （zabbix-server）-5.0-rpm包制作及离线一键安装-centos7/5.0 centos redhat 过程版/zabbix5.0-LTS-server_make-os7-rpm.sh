#!/bin/bash
clear
echo -e "\033[33m
--------------------------zabbix5.0-LTS-server-rpm包制作-（此主机需要外网）---------------------
适用版本：
内核2.6、3.0 测试正常
只支持处理器x86_64
linux OS版本6、7、8
Creator:
反馈：mail: pzl960505@163.com
--------------
----------------------------使用方法-----------------------
1.运行脚本
sh zabbix5.0-LTS-server_make_rpm.sh
2.根据提示输入以下信息，按回车进行下一步
—
===========================-请按提示输入以下信息-============================
\033[0m
"
sleep 5
echo -e "\033[31m【0】请输入需要离线安装的主机OS版本(6或者7或者8)并按回车确认：\033[0m"
read OS
echo '即将开始自动安装'
echo "第一步：下载zabbix源"
rpm -Uvh https://repo.zabbix.com/zabbix/5.0/rhel/"$OS"/x86_64/zabbix-release-5.0-1.el"$OS".noarch.rpm
yum clean all
sed -i '11 s\0\1\g' /etc/yum.repos.d/zabbix.repo
echo "第二步：下载yumdowaloader"
yum install yum-utils -y
echo "第三步：将所有依赖、应用制作成rpm包"
mkdir -p /zabbix5.0_LTS-os"$OS"-rpm
yumdownloader centos-release-scl zabbix-server-mysql.x86_64 zabbix-agent  zabbix-web-mysql-scl zabbix-nginx-conf-scl mariadb-server mariadb php-gd --resolve --dest /zabbix5.0_LTS-os"$OS"-rpm
echo "第四步：打包成压缩包，并查看"
cd /
tar -cvzf /root/zabbix5.0_LTS-os"$OS"-rpm.tar.gz /zabbxi5.0_LTS-os"$OS"-rpm/*
cd ~
echo -e "\033[32m
-------------------------rpm已打包完成，请将下面的压缩包上传到你的内网主机上进行离线安装zabbix-server+agent----------------------------------
$(ls zabbix5.0_LTS-os*)
\033[0m
"
