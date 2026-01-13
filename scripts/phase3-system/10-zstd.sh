#!/bin/bash
# LFS 12.4 - 8.10. Zstd-1.5.7
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"
PKG_NAME="zstd"
check_built "$PKG_NAME" && exit 0
extract "zstd"

make $MAKEFLAGS
make PREFIX=/usr install

rm -v /usr/lib/libzstd.a

cd .. && rm -rf "zstd-"*
mark_built "$PKG_NAME"
