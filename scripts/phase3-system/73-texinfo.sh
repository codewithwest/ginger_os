#!/bin/bash
# LFS 12.4 - 8.73. Texinfo-7.2
source "/scripts/common.sh"
PKG_NAME="texinfo"
ARCHIVE="texinfo-7.2.tar.xz"
DIR_NAME="texinfo-7.2"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr
make $MAKEFLAGS
make install
make TEXMF=/usr/share/texmf install-tex
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
