#!/bin/bash

function LOG() {
    echo "[`date +%Y%m%d-%H:%M:%S`] $@" >&2
}

function DIE() {
    LOG $@
    exit 1
}

[ X`command -v git` = X ] && DIE "git is not installed!"
sunshine=`hadoop version | grep 2.6.0-cdh5.10.0 | head -n 1 2>/dev/null`
#[ "X`command -v hadoop`" = X -o "X$sunshine" = X ] && DIE "hadoop client(sunshine) is not installed!"

TIME=$(date +%Y%m%d-%H%M%S)

TGZ_NAME="spark-2.1.1-bin-2.6.0-cdh5.10.0-sogou-p0.12"
LATEST_TGZ=$TGZ_NAME.tgz

LOCAL_INSTALL_DIR=/opt

HDFS_DIST_ROOT_DIR=/user/spark/dist
HDFS_DIST_LATEST_DIR=$HDFS_DIST_ROOT_DIR/latest

SPARK_CONFIG_GIT_REPO=http://gitlab.dev.sogou-inc.com/sogou-spark/spark-config.git
SPARK_CONFIG_GIT_BRANCH=sogou-2.1-cdh5.10.0-for-diablo

LOCAL_INSTALL_TMP_ROOT=/tmp/.spark; mkdir -p $LOCAL_INSTALL_TMP_ROOT
LOCAL_INSTALL_TMP_DIR=`mktemp -d -p $LOCAL_INSTALL_TMP_ROOT`
pushd $LOCAL_INSTALL_TMP_DIR

# choose the active namenode
#SUNSHINE_NN_HFTP_1=hdfs://master03.sunshine.sogou:8020/
#SUNSHINE_NN_HFTP_2=hdfs://master04.sunshine.sogou:8020/
#SUNSHINE_NN_HFTP=$SUNSHINE_NN_HFTP_1
#if [ `hadoop fs -ls $SUNSHINE_NN_HFTP_1 >/dev/null 2>&1; echo $?` -eq 1 ]
#then
#    if [ `hadoop fs -ls $SUNSHINE_NN_HFTP_2 >/dev/null 2>&1; echo $?` -eq 1 ]
#    then
#        DIE "both $SUNSHINE_NN_HFTP_1 and $SUNSHINE_NN_HFTP_2 are not avalable"
#    else
#        SUNSHINE_NN_HFTP=$SUNSHINE_NN_HFTP_2
#    fi
#fi
DIABLO_NN_HFTP=viewfs://diabloX/
LOG "step-1: download latest spark tgz file: $LATEST_TGZ"
hadoop fs -get $DIABLO_NN_HFTP/$HDFS_DIST_LATEST_DIR/$LATEST_TGZ .
[ $? -ne 0 ] && DIE "fail to download $LATEST_TGZ"

LOG "step-2: decompres spark tgz file"
tar -xzvf $LATEST_TGZ

LOCAL_CONFIG_TMP_ROOT=$LOCAL_CONFIG_TMP_DIR/.config; mkdir -p $LOCAL_CONFIG_TMP_ROOT
LOCAL_CONFIG_TMP_DIR=`mktemp -d -p $LOCAL_CONFIG_TMP_ROOT`
pushd $LOCAL_INSTALL_TMP_DIR
LOG "step-3: git clone spark-config project to local"
 git clone -b $SPARK_CONFIG_GIT_BRANCH $SPARK_CONFIG_GIT_REPO
#curl http://gitlab.dev.sogou-inc.com/sogou-spark/spark-config/repository/archive.tar.bz2?ref=$SPARK_CONFIG_GIT_BRANCH | tar -jvx
LOG "step-4: copy file to spark project"
## cd spark-config
cd spark-config
for f in $(ls conf)
do
    LOG "copy config file $f to /opt/spark/conf ..."
    cp conf/$f $LOCAL_INSTALL_TMP_DIR/$TGZ_NAME/conf
done
mkdir -p $LOCAL_INSTALL_TMP_DIR/$TGZ_NAME/test
for f in $(ls test)
do
    LOG "copy test file $f to /opt/spark/test ..."
    cp test/$f $LOCAL_INSTALL_TMP_DIR/$TGZ_NAME/test
done
for f in $(ls usr/bin)
do
    LOG "copy executable file $f to /usr/bin ..."
    cp usr/bin/$f /usr/bin
done
popd
rm -fr $LOCAL_CONFIG_TMP_ROOT

LOG "step-5: backup old spark project, move lastest spark project to dir $LOCAL_INSTALL_DIR/spark"
[ -d $LOCAL_INSTALL_DIR/spark ] && mv $LOCAL_INSTALL_DIR/spark $LOCAL_INSTALL_DIR/spark-bak-$TIME
mv $LOCAL_INSTALL_TMP_DIR/$TGZ_NAME $LOCAL_INSTALL_DIR/spark

popd

LOG "step-6: clean up tmp files"
rm -fr $LOCAL_INSTALL_TMP_ROOT

LOG "step-7: add hive-site.xml softlink"
#cd $LOCAL_INSTALL_DIR/spark/conf; ln -s /opt/datadir/conf/hive-site.xml .

LOG "Spark installed succeed!!!"
