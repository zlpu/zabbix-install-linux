#准备在线包
wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-4+ubuntu22.04_all.deb
dpkg -i zabbix-release_6.0-4+ubuntu22.04_all.deb
sudo apt-get install apt-transport-https curl
sudo mkdir -p /etc/apt/keyrings
sudo curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'
cat >> /etc/apt/sources.list.d/mariadb.sources <<EOF
# MariaDB 10.11 repository list - created 2023-12-10 03:20 UTC
# https://mariadb.org/download/
X-Repolib-Name: MariaDB
Types: deb
# deb.mariadb.org is a dynamic mirror if your preferred mirror goes offline. See https://mariadb.org/mirrorbits/ for details.
# URIs: https://deb.mariadb.org/10.11/ubuntu
URIs: https://mirrors.aliyun.com/mariadb/repo/10.11/ubuntu
Suites: jammy
Components: main main/debug
Signed-By: /etc/apt/keyrings/mariadb-keyring.pgp
EOF
sudo apt-get install mariadb-server

apt update


#安装工具：
apt install dpkg-* -y
#创建一个目录如下：
mkdir -p /opt/offline-packages/archives
chmod 777 /opt
cd /opt/offline-packages/archives
#执行如下命令会将vim的递归依赖都下载到/opt/offline-packages/archives目录内：
sudo apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances mariadb-server zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent | grep "^\w" | sort -u)
#建立依赖的命令
cd /opt/offline-packages
sudo dpkg-scanpackages -m . /dev/null | gzip -9c > Packages.gz
cp Packages.gz ./archives
#带上-m，会将所有包全部建立依赖关系到 Packages.gz中，如此会有重复，但无需剔除重复的包

#最后打包供其他服务器使用
cd /opt
tar -zcvf zabbix-server6.0-offlineinstall-ubuntu22.04-apt-packages.tar.gz offline-packages


#离线源应用
#将上边打包的离线包发送到目标机器上，解压

sudo tar -zxvf zabbix-server6.0-offlineinstall-ubuntu22.04-apt-packages.tar.gz -C /opt
# 写入本地源，如有需要，提取备份原有源
echo "deb [trusted=yes] file:///opt/offline-apt-packages  archives/"| sudo tee /etc/apt/sources.list 
#deb [trusted=yes] file:///opt/offline-apt-packages archives/

#更新源
sudo apt-get update