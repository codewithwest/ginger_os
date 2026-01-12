#!/bin/bash
# LFS 12.4 - 8.33. Gettext-0.26
source "/scripts/common.sh"
PKG_NAME="gettext"
ARCHIVE="gettext-0.26.tar.xz"
DIR_NAME="gettext-0.26"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-0.26
make $MAKEFLAGS
make install
chmod -v 0755 /usr/lib/preloadable_libintl.so
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
