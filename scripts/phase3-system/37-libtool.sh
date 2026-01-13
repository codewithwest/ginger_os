#!/bin/bash
# LFS 12.4 - 8.37. Libtool-2.5.4
source "/scripts/common.sh"
PKG_NAME="libtool"
check_built "$PKG_NAME" && exit 0
extract "libtool"

./configure --prefix=/usr
make $MAKEFLAGS
make install

rm -fv /usr/lib/libltdl.a

cd .. && rm -rf "libtool-"*
mark_built "$PKG_NAME"
