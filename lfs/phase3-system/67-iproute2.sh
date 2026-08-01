#!/bin/bash
# LFS 13.0  - 8.67. IPRoute2-6.13.0
source "/lfs/lib/common.sh"
PKG_NAME="iproute2"
check_built "$PKG_NAME" && exit 0
extract "iproute2"

sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8

make NETNS_RUN_DIR=/run/netns $MAKEFLAGS
make SBINDIR=/usr/sbin install

install -vDm644 COPYING README* -t /usr/share/doc/iproute2-${IPROUTE2_VERSION}

cleanup
mark_built "$PKG_NAME"
