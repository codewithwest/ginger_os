#!/bin/bash
# LFS 12.4 - 8.26. Libcap-2.76
source "/scripts/common.sh"
PKG_NAME="libcap"
ARCHIVE="libcap-2.76.tar.xz"
DIR_NAME="libcap-2.76"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
sed -i '/install -m.*STALIBNAME/d' libcap/Makefile
make prefix=/usr lib=lib $MAKEFLAGS
make prefix=/usr lib=lib install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
