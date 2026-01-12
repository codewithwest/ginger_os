#!/bin/bash
# LFS 12.4 - 6.10. Grep-3.12
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="grep-temp"
PKG_VERSION="$GREP_VERSION"
ARCHIVE="grep-$GREP_VERSION.tar.xz"
DIR_NAME="grep-$GREP_VERSION"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make $MAKEFLAGS
make DESTDIR=$LFS install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
