#!/bin/bash
# LFS 12.4 - 8.46. Autoconf-2.72
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="autoconf"
check_built "$PKG_NAME" && exit 0
extract "autoconf"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "autoconf-"*
mark_built "$PKG_NAME"
