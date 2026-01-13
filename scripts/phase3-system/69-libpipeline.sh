#!/bin/bash
# LFS 12.4 - 8.69. Libpipeline-1.5.8
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"
PKG_NAME="libpipeline"
check_built "$PKG_NAME" && exit 0
extract "libpipeline"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "libpipeline-"*
mark_built "$PKG_NAME"
