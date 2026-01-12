#!/bin/bash
# LFS 12.4 - 8.14. Bc-7.0.3
source "/scripts/common.sh"
PKG_NAME="bc"
ARCHIVE="bc-7.0.3.tar.xz"
DIR_NAME="bc-7.0.3"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
CC=gcc ./configure --prefix=/usr -G -O3 -r
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
