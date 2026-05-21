#!/bin/bash
# LFS 13.0  - 8.61. Diffutils-3.11
source "/lfs/lib/common.sh"
PKG_NAME="diffutils"
check_built "$PKG_NAME" && exit 0
extract "diffutils"

./configure --prefix=/usr

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
