#!/bin/bash
# LFS 12.4 - 8.9. Lz4-1.10.0
source "/scripts/common.sh"
PKG_NAME="lz4"
ARCHIVE="lz4-1.10.0.tar.gz"
DIR_NAME="lz4-1.10.0"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
make BUILD_STATIC=no PREFIX=/usr
make BUILD_STATIC=no PREFIX=/usr install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
