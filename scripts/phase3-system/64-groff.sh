#!/bin/bash
# LFS 12.4 - 8.64. Groff-1.23.0
source "/scripts/common.sh"
PKG_NAME="groff"
ARCHIVE="groff-1.23.0.tar.gz"
DIR_NAME="groff-1.23.0"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
