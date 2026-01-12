#!/bin/bash
# LFS 12.4 - 6.9. Gawk-5.3.2
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="gawk-temp"
ARCHIVE="gawk-5.3.2.tar.xz"
DIR_NAME="gawk-5.3.2"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make $MAKEFLAGS
make DESTDIR=$LFS install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
