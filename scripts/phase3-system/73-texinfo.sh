#!/bin/bash
# LFS 12.4 - 8.73. Texinfo-7.2
source "$(dirname "$(readlink -f "$0")")/common.sh"
PKG_NAME="texinfo"
check_built "$PKG_NAME" && exit 0
extract "texinfo"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "texinfo-"*
mark_built "$PKG_NAME"
# Optional: install-tex
