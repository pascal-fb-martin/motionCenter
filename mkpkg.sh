#!/bin/sh
#
# Crude distribution package builder for motionCenter.
#
PACKAGE="motionCenter-`date +%F`.tgz"

mkdir -p packages
tar -cvf packages/$PACKAGE public scripts config install.sh README.md LICENSE

