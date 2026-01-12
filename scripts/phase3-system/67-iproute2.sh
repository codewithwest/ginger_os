#!/bin/bash
# LFS 12.4 - 8.67. IPRoute2-6.16.0
source "/scripts/common.sh"
PKG_NAME="iproute2"
ARCHIVE="iproute2-6.16.0.tar.xz"
DIR_NAME="iproute2-6.16.0"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
sed -i / ARPD /d Makefile
rm -fv man/man8/arpd.8
make NETNS_RUN_DIR=/run/netns $MAKEFLAGS
make DESTDIR= install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
