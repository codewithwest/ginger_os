#!/bin/bash
# LFS 13.0  - 8.26. Libcap-2.76
source "/lfs/lib/common.sh"
PKG_NAME="libcap"
check_built "$PKG_NAME" && exit 0
extract "libcap"

sed -i '/install -m.*STA/d' libcap/Makefile


make prefix=/usr lib=lib $MAKEFLAGS

make prefix=/usr lib=lib install

cleanup
mark_built "$PKG_NAME"
