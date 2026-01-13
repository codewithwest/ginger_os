#!/bin/bash
# LFS 12.4 - 8.67. IPRoute2-6.13.0
source "/scripts/common.sh"
PKG_NAME="iproute2"
check_built "$PKG_NAME" && exit 0
extract "iproute2"
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8
make $MAKEFLAGS
make SBINDIR=/usr/sbin install
cd .. && rm -rf "iproute2-"*
mark_built "$PKG_NAME"
