#!/bin/sh
#
# Crude installation script for motionCenter.
#
# This script exists because it is much easier than making a .deb or .rpm,
# and it should work on most Linux installations.
#

#  Create the directories.

INSTALLPATH=$1
if [ $# -lt 1 ] ; then
   INSTALLPATH=/storage/motion
fi
if [ ! -d $INSTALLPATH ] ; then
   echo "creating $INSTALLPATH"
   mkdir -p $INSTALLPATH
fi

for dir in public scripts videos config ; do
   mkdir -p $INSTALLPATH/$dir
done


# Install the software itself.

for dir in public scripts ; do
  cp -uv $dir/* $INSTALLPATH/$dir
done

for file in config/*.rc ; do
  if [ ! -e $INSTALLPATH/$file ] ; then
    cp -v $file $INSTALLPATH/config
  fi
done


# Set proper ownership for all these files.

for dir in public scripts videos config ; do
   chown -R motion:motion $INSTALLPATH/$dir
done


# Install the tclHttpd default's configuration.

SYSCONFIG=/etc/default/tclhttpd
cp -uv $INSTALLPATH/config/tclhttpd.rc $SYSCONFIG


# Install the SYS V style init script.

if [ ! -e /etc/init.d/tclhttpd ] ; then
   cp -uv sysv/tclhttpd.init /etc/init.d
   chown root:root /etc/init.d/tclhttpd
   chmod 755 /etc/init.d/tclhttpd
fi

