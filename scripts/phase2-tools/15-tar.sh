#!/bin/bash
# LFS 12.4 - 6.15. Tar-1.35
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="tar-temp"
ARCHIVE="tar-1.35.tar.xz"
DIR_NAME="tar-1.35"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess)
make $MAKEFLAGS
make DESTDIR=$LFS install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
