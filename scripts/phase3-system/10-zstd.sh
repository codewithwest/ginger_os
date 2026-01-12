#!/bin/bash
# LFS 12.4 - 8.10. Zstd-1.5.7
source "/scripts/common.sh"
PKG_NAME="zstd"
ARCHIVE="zstd-1.5.7.tar.gz"
DIR_NAME="zstd-1.5.7"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
sed -i 's/$(ZSTD_LIB_MIN)/$(ZSTD_LIB_MAX)/' lib/Makefile
make prefix=/usr
make prefix=/usr install
rm -v /usr/lib/libzstd.a
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
