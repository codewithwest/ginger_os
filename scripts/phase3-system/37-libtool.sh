#!/bin/bash
# LFS 12.4 - 8.37. Libtool-2.5.4
source "/scripts/common.sh"
PKG_NAME="libtool"
ARCHIVE="libtool-2.5.4.tar.xz"
DIR_NAME="libtool-2.5.4"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr
make $MAKEFLAGS
make install
rm -fv /usr/lib/libltdl.a
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
