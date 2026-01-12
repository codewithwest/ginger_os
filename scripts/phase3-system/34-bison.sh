#!/bin/bash
# LFS 12.4 - 8.34. Bison-3.8.2
source "/scripts/common.sh"
PKG_NAME="bison"
ARCHIVE="bison-3.8.2.tar.xz"
DIR_NAME="bison-3.8.2"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
