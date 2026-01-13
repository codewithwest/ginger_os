#!/bin/bash
# LFS 12.4 - 8.64. Groff-1.23.0
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"
PKG_NAME="groff"
check_built "$PKG_NAME" && exit 0
extract "groff"
PAGE=A4 ./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "groff-"*
mark_built "$PKG_NAME"
