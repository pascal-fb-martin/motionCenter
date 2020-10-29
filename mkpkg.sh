#!/bin/sh
#
# Crude distribution package builder for motionCenter.
#
PACKAGE="motionCenter-`date +%F`.tgz"

mkdir -p packages
tar -cf packages/$PACKAGE public scripts config sysv install.sh README.md LICENSE
echo "Generated package packages/$PACKAGE"

