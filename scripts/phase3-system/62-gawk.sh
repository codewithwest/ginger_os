#!/bin/bash
# LFS 12.4 - 8.62. Gawk-5.3.1
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"
PKG_NAME="gawk"
check_built "$PKG_NAME" && exit 0
extract "gawk"
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "gawk-"*
mark_built "$PKG_NAME"
