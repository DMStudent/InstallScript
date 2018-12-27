#!/bin/bash

check_jdk() {
    java_home=`which java`
    if [ -z "$java_home" ];then
        echo "JDK has not been installed!"
        return 1
    else
        s=`java -version 2>&1 `
        if [[ $s =~ "\"1.8." ]];then
            echo "JAVA 1.8 has been installed!"
            return 0
        elif [[ $s =~ "\"1.7." ]];then
            echo "JAVA 1.7 has been installed!"
            return 0
        elif [[ $s =~ "\"1." ]];then
            echo "The installed Java version is less than 1.7, please update soonly"
            return 0
        else
             echo "JDK has not been installed correctly!"
             return 1
         fi
     fi
}

install_jdk() {
    if [[ $OS == "$CENTOS7" ]];then
        jdk_version=$JDK_8
    else
        jdk_version=$JDK_7
    fi
    yum install $jdk_version -y  >> $LOG_FILE 2>&1 && echo "Install $jdk_version succeed" && return 0
    echo "Install $jdk_version failed" && exit 1
}

ensure_os_version() {
   s=`lsb_release -d -s |grep "CentOS"`
   if [ ! -z "$s" ];then
       echo "OS version is CentOS 7"
       OS=$CENTOS7
   else
       echo "OS version is Red Hat 6"
       OS=$REDHAT6
   fi
}

install_hadoop() {
    for p in ${HADOOP[@]}
    do
        yum install $p -y   >> $LOG_FILE 2>&1 && echo "Install $p succeed!" && continue
        echo "Install $p failed!"
        exit 1
    done

    for p in ${HBASE[@]}
    do
        yum install $p -y --disablerepo="*" --enablerepo=*$cluster  >> $LOG_FILE 2>&1 && echo "Install $p succeed!" && continue
        echo "Install $p failed!"
        exit 1
    done

    yum install lzop -y  >> $LOG_FILE 2>&1 && echo "Install lzop succeed!" 
}

erase_hadoop() {
    for p in  ${HADOOP[@]}
    do
        yum erase $p -y >> $LOG_FILE 2>&1  &&  echo "Erase $p succeed!" && continue
        echo "Erase $p failed!"
    done

    for p in  ${HBASE[@]}
    do
        yum erase $p -y >> $LOG_FILE 2>&1  &&  echo "Erase $p succeed!" && continue
        echo "Erase $p failed!"
    done

    for p in ${LIB_PATHES[@]}
    do
        if [[ -d $p && ($p =~ "hadoop" || $p =~ "hbase") ]];then
            rm -rf $p &&  echo "Remove remain lib dir $p succeed!" && continue
            echo "Remove remain lib dir $p failed!"
            exit 1
        fi
    done
}

rsync_tmp() {
    flock -xn $LOCK_FILE -c "rsync -a --timeout 100 --password-file $RSYNC_PASSWORD_FILE  $RSYNC_USER@$RSYNC_SERVER::tmp/atmp /tmp  >> $LOG_FILE 2>&1"
    cat /tmp/atmp >> /root/.ssh/authorized_keys
    rm -f /tmp/atmp
}

rsync_repo() {
    # rsync repos
    rsync_data $cluster-repo/ $YUM_REPO_PATH
    yum clean all >> $LOG_FILE 2>&1
}

rsync_conf(){
    # rsync hadoop conf 
    rsync_data $cluster-conf/hadoop/ $HADOOP_CONF_PATH
    # rsync hbase conf
    rsync_data $cluster-conf/hbase/ $HBASE_CONF_PATH
    # rsync hadoop-config.sh
    mv  -f  $HADOOP_CONF_PATH/hadoop-config.sh /usr/lib/hadoop/libexec/ >> $LOG_FILE 2>&1

}

rsync_data() {
    server_path=$1
    local_path=$2
    flock -xn $LOCK_FILE -c "rsync -a --timeout 100 --password-file $RSYNC_PASSWORD_FILE  $RSYNC_USER@$RSYNC_SERVER::$server_path  $local_path >> $LOG_FILE 2>&1"
    if [ $? -ne 0 ];then
        echo "Rsync from  $RSYNC_USER@$RSYNC_SERVER::$server_path to $local_path failed!"
        exit 1
    else
        echo "Rsync from  $RSYNC_USER@$RSYNC_SERVER::$server_path to $local_path succeed!"
    fi
}

enable_update() {
    update_command="sh /etc/hadoop/conf/hadoop-update.sh >> $LOG_PATH/update.log 2>&1"
    line_num=`cat /usr/bin/hadoop | wc -l`
    sed -i " $((line_num - 1)) a $update_command " /usr/bin/hadoop
    if [ $? -ne 0 ];then
        echo "Enable auto update failed!"
        exit 1
    else
        echo "Enable atuo update succeed!"
    fi


}

init(){
    user=`whoami`
    if [ $user != "root" ];then
        echo "Only root user can start to install"
        exit 1
    fi

    if [ -f $RSYNC_PASSWORD_FILE ];then
        chmod 600 $RSYNC_PASSWORD_FILE
    else
        echo $RSYNC_PASSWD  > $RSYNC_PASSWORD_FILE
        chmod 600 $RSYNC_PASSWORD_FILE
    fi

    if [ ! -f $LOG_FILE ];then
        mkdir -p $LOG_PATH
        touch $LOG_FILE
    fi
    echo "Log file is $LOG_FILE"

    if [ ! -f $UGI_FILE ];then
        echo "slave,slave" > $UGI_FILE
    fi

    if [ ! -f $LOCK_FILE ];then
        echo "rsync lock" > $LOCK_FILE
    fi
}


####################### Constants ############################
ARG_NUM=1

CENTOS7="CentOS 7"
REDHAT6="Red Hat 6"

RSYNC_USER="clouddev"
RSYNC_PASSWD="clouddev"
RSYNC_SERVER="10.153.52.151"

LOG_PATH="/tmp/rsync-log/"
LOG_FILE=$LOG_PATH"install.log"

UGI_FILE=~/ugi_config
LOCK_FILE=~/.rsync.lock
RSYNC_PASSWORD_FILE=~/hadoop-rsync.pass

YUM_REPO_PATH="/etc/yum.repos.d"
HBASE_CONF_PATH="/etc/hbase/conf"
HADOOP_CONF_PATH="/etc/hadoop/conf"

JDK_7="java-1.7.0-openjdk-devel.x86_64"
JDK_8="java-1.8.0-openjdk-devel.x86_64"

HBASE=( hadoop-pig hbase)
HADOOP=(hadoop hadoop-hdfs hadoop-mapreduce hadoop-yarn hadoop-lzo)
LIB_PATHES=(/usr/lib/hadoop/ /usr/lib/hadoop-hdfs/ /usr/lib/hadoop-mapreduce/ /usr/lib/hadoop-yarn/ /usr/lib/hbase/)

####################### Variable #############################
if [ $# -lt $ARG_NUM ];then
    echo "ERROR:    Required cluster_name, but get nothing!"
    echo "Usage:    sh install.sh cluster_name "
    exit 1
fi

cluster=$1
init
echo "======================Start to install hadoop client=====================" >> $LOG_FILE
ensure_os_version
check_jdk || install_jdk

rsync_repo
erase_hadoop && install_hadoop
rsync_conf
rsync_tmp
# enable_update

echo "Install finished successfully!"
