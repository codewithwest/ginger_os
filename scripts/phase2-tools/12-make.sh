#!/bin/bash
# LFS 12.4 - 6.12. Make-4.4.1
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="make-temp"
ARCHIVE="make-4.4.1.tar.gz"
DIR_NAME="make-4.4.1"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr   \
            --without-guile \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make $MAKEFLAGS
make DESTDIR=$LFS install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
