#!/bin/bash
# LFS 12.4 - 8.66. Gzip-1.14
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="gzip"
check_built "$PKG_NAME" && exit 0
extract "gzip"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "gzip-"*
mark_built "$PKG_NAME"
# Note: Host gzip is usually already present, but this builds it for the target.
