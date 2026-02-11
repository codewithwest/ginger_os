#!/bin/bash
# LFS 12.4 - 8.9. Lz4-1.10.0
source "/scripts/lib/common.sh"
PKG_NAME="lz4"
check_built "$PKG_NAME" && exit 0
extract "lz4"

make $MAKEFLAGS
make PREFIX=/usr install

cd .. && rm -rf "lz4-"*
mark_built "$PKG_NAME"
