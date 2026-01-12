#!/bin/bash
# LFS 12.4 - 8.47. Automake-1.18.1
source "/scripts/common.sh"
PKG_NAME="automake"
ARCHIVE="automake-1.18.1.tar.xz"
DIR_NAME="automake-1.18.1"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.18.1
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
