#!/bin/bash
# LFS 12.4 - 8.10. Zstd-1.5.7
source "/scripts/lib/common.sh"
PKG_NAME="zstd"
check_built "$PKG_NAME" && exit 0
extract "zstd"

make $MAKEFLAGS
make PREFIX=/usr install

rm -v /usr/lib/libzstd.a

cleanup
mark_built "$PKG_NAME"
