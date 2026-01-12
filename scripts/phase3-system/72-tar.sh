#!/bin/bash
# LFS 12.4 - 8.72. Tar-1.35
source "/scripts/common.sh"
PKG_NAME="tar-final"
ARCHIVE="tar-1.35.tar.xz"
DIR_NAME="tar-1.35"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
