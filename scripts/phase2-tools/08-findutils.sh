#!/bin/bash
# LFS 12.4 - 6.8. Findutils-4.10.0
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="findutils-temp"
PKG_VERSION="$FINDUTILS_VERSION"
ARCHIVE="findutils-$FINDUTILS_VERSION.tar.xz"
DIR_NAME="findutils-$FINDUTILS_VERSION"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr                   \
            --localstatedir=/var/lib/locate \
            --host=$LFS_TGT                 \
            --build=$(build-aux/config.guess)
make $MAKEFLAGS
make DESTDIR=$LFS install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
