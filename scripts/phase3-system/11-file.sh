#!/bin/bash
# LFS 12.4 - 8.11. File-5.46
source "/scripts/common.sh"
PKG_NAME="file"
ARCHIVE="file-5.46.tar.gz"
DIR_NAME="file-5.46"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
