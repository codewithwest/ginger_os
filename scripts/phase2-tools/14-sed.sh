#!/bin/bash
# LFS 12.4 - 6.14. Sed-4.9
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="sed-temp"
ARCHIVE="sed-4.9.tar.xz"
DIR_NAME="sed-4.9"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make $MAKEFLAGS
make DESTDIR=$LFS install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
