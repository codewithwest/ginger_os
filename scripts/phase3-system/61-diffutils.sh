#!/bin/bash
# LFS 12.4 - 8.61. Diffutils-3.11
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="diffutils"
check_built "$PKG_NAME" && exit 0
extract "diffutils"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "diffutils-"*
mark_built "$PKG_NAME"
