#!/bin/bash
# LFS 12.4 - 8.33. Gettext-0.23.1
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="gettext"
check_built "$PKG_NAME" && exit 0
extract "gettext"
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-0.23.1
make $MAKEFLAGS
make install
chmod -v 0755 /usr/lib/preloadable_libintl.so
cd .. && rm -rf "gettext-"*
mark_built "$PKG_NAME"
