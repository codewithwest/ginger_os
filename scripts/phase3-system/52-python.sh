#!/bin/bash
# LFS 12.4 - 8.52. Python-3.13.7
source "$(dirname "$(readlink -f "$0")")/common.sh"
PKG_NAME="python"
check_built "$PKG_NAME" && exit 0
extract "Python"
./configure --prefix=/usr        \
            --enable-shared      \
            --with-system-expat  \
            --enable-optimizations
make $MAKEFLAGS
make install
cd .. && rm -rf "Python-"*
mark_built "$PKG_NAME"
