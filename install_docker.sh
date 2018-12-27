# -*- coding: utf-8 -*-
#########################################################################
# File Name: install_docker.sh
# Author: wangyuan
# mail: wangyuan214159@sogou-inc.com
# Created Time: 2018年12月27日 星期四 16时25分37秒
#########################################################################
#!/bin/bash

# 环境初始化：指定用户需要有sudo权限

# step 1: 移除旧的docker
sudo yum remove docker \
                docker-client \
                docker-client-latest \
                docker-common \
                docker-latest \
                docker-latest-logrotate \
                docker-logrotate \
                docker-selinux \
                docker-engine-selinux \
                docker-engine \
                docker-ce
sudo rm -rf /var/lib/docker

# step 1: 安装相关组件和配置yum源
sudo yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2
sudo yum-config-manager \
    --add-repo \
    http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
# step 2: 配置缓存
sudo yum makecache fast
# step 3: 执行安装
sudo yum install docker-ce
# step 4: 配置镜像下载加速
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://xxx.mirror.aliyuncs.com"]
}
EOF
# step 5: 启动docker并配置开机启动
sudo systemctl start docker
sudo systemctl enable docker
# step 6: 配置当前用户对docker命令的执行权限
sudo groupadd docker
sudo gpasswd -a ${USER} docker
sudo systemctl restart docker

