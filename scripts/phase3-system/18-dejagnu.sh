#!/bin/bash
# LFS 12.4 - 8.18. DejaGNU-1.6.3
source "/scripts/common.sh"
PKG_NAME="dejagnu"
ARCHIVE="dejagnu-1.6.3.tar.gz"
DIR_NAME="dejagnu-1.6.3"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
mkdir -v build
cd build
../configure --prefix=/usr
make $MAKEFLAGS
make install
cd ../.. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
