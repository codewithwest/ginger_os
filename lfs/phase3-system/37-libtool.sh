#!/bin/bash
# LFS 13.0  - 8.37. Libtool-2.5.4
source "/lfs/lib/common.sh"
PKG_NAME="libtool"
check_built "$PKG_NAME" && exit 0
extract "libtool"

./configure --prefix=/usr
make $MAKEFLAGS
make install

rm -fv /usr/lib/libltdl.a

cleanup
mark_built "$PKG_NAME"
