#!/bin/bash
# LFS 12.4 - 8.19. Pkgconf-2.5.1
source "/scripts/common.sh"
PKG_NAME="pkgconf"
ARCHIVE="pkgconf-2.5.1.tar.xz"
DIR_NAME="pkgconf-2.5.1"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr              \
            --disable-static           \
            --docdir=/usr/share/doc/pkgconf-2.5.1
make $MAKEFLAGS
make install
ln -sv pkgconf /usr/bin/pkg-config
ln -sv pkgconf.1 /usr/share/man/man1/pkg-config.1
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
