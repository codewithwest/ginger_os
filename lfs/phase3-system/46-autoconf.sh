#!/bin/bash
# LFS 13.0  - 8.46. Autoconf-2.72
source "/lfs/lib/common.sh"
PKG_NAME="autoconf"
check_built "$PKG_NAME" && exit 0
extract "autoconf"

./configure --prefix=/usr
make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
