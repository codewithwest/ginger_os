#!/bin/bash
# LFS 13.0  - 8.66. Gzip-1.14
source "/lfs/lib/common.sh"
PKG_NAME="gzip"
check_built "$PKG_NAME" && exit 0
extract "gzip"

./configure --prefix=/usr

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
# Note: Host gzip is usually already present, but this builds it for the target.
