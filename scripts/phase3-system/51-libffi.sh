#!/bin/bash
# LFS 12.4 - 8.51. Libffi-3.5.2
source "/scripts/common.sh"
PKG_NAME="libffi"
ARCHIVE="libffi-3.5.2.tar.gz"
DIR_NAME="libffi-3.5.2"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr --disable-static --with-gcc-arch=native
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
