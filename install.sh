#!/bin/sh
#
# Crude installation script for motionCenter.
#
INSTALLPATH=$1
if [ $# -lt 1 ] ; then
   INSTALLPATH=/storage/motion
fi
if [ ! -d $INSTALLPATH ] ; then
   echo "creating $INSTALLPATH"
   mkdir -p $INSTALLPATH
fi

for dir in public scripts ; do
  mkdir -p $INSTALLPATH/$dir
  cp -uv $dir/* $INSTALLPATH/$dir
done

mkdir -p $INSTALLPATH/config
for file in config/*.rc ; do
  if [ ! -e $INSTALLPATH/$file ] ; then
    cp -v $file $INSTALLPATH/config
  fi
done

mkdir -p $INSTALLPATH/videos

SYSCONFIG=/etc/default/tclhttpd
cp -uv $INSTALLPATH/config/tclhttpd.rc $SYSCONFIG

