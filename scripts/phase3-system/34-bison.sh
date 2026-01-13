#!/bin/bash
# LFS 12.4 - 8.34. Bison-3.8.2
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"
PKG_NAME="bison"
check_built "$PKG_NAME" && exit 0
extract "bison"

./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2


make $MAKEFLAGS
make install

cd .. && rm -rf "bison-"*
mark_built "$PKG_NAME"
