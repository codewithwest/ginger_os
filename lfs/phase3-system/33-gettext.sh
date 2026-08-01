#!/bin/bash
# LFS 13.0  - 8.33. Gettext-0.23.1
source "/lfs/lib/common.sh"
PKG_NAME="gettext"
check_built "$PKG_NAME" && exit 0
extract "gettext"

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-${GETTEXT_VERSION}

make $MAKEFLAGS
make install

chmod -v 0755 /usr/lib/preloadable_libintl.so

cleanup
mark_built "$PKG_NAME"
