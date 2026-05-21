#!/bin/bash
# LFS 13.0  - 8.69. Libpipeline-1.5.8
source "/lfs/lib/common.sh"
PKG_NAME="libpipeline"
check_built "$PKG_NAME" && exit 0
extract "libpipeline"

./configure --prefix=/usr
make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
