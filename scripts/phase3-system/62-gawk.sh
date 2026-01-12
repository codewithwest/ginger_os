#!/bin/bash
# LFS 12.4 - 8.62. Gawk-5.3.2
source "/scripts/common.sh"
PKG_NAME="gawk-final"
ARCHIVE="gawk-5.3.2.tar.xz"
DIR_NAME="gawk-5.3.2"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr
make $MAKEFLAGS
make LN='ln -f' install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
