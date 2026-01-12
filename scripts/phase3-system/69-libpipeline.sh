#!/bin/bash
# LFS 12.4 - 8.69. Libpipeline-1.5.8
source "/scripts/common.sh"
PKG_NAME="libpipeline"
ARCHIVE="libpipeline-1.5.8.tar.gz"
DIR_NAME="libpipeline-1.5.8"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
