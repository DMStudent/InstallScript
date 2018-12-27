#1.添加mysql yum Repo源
wget http://repo.mysql.com//mysql57-community-release-el7-7.noarch.rpm

#2.安装mysql的RPM源包
sudo rpm -Uvh mysql57-community-release-el7-7.noarch.rpm

#3.查看mysql在yum里面的列表
sudo yum repolist all | grep mysql

#4.通过yum安装mysql
sudo yum install mysql-community-server


echo '
#####################################################
#查看默认密码：
sudo grep 'temporary password' /var/log/mysqld.log

#启动mysql,修改密码规则，简化规则
sudo service mysqld start
set global validate_password_policy=0;
set global validate_password_length=1;

#修改密码：
set password for root@localhost = password('root');

#####################################################
'

