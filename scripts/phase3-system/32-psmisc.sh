#!/bin/bash
# LFS 12.4 - 8.32. Psmisc-23.7
source "/scripts/common.sh"
PKG_NAME="psmisc"
ARCHIVE="psmisc-23.7.tar.xz"
DIR_NAME="psmisc-23.7"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
