#!/bin/bash
# LFS 12.4 - 8.26. Libcap-2.76
source "/scripts/lib/common.sh"
PKG_NAME="libcap"
check_built "$PKG_NAME" && exit 0
extract "libcap"

sed -i '/install -m.*STA/d' libcap/Makefile


make prefix=/usr lib=lib $MAKEFLAGS

make prefix=/usr lib=lib install

cd .. && rm -rf "libcap-"*
mark_built "$PKG_NAME"
