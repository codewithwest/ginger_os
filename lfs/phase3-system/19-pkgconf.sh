#!/bin/bash
# LFS 13.0  - 8.19. Pkgconf-2.3.0
source "/lfs/lib/common.sh"
PKG_NAME="pkgconf"
check_built "$PKG_NAME" && exit 0
extract "pkgconf"

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/pkgconf-${PKGCONF_VERSION}

make $MAKEFLAGS
make install

ln -sfv pkgconf   /usr/bin/pkg-config
ln -sfv pkgconf.1 /usr/share/man/man1/pkg-config.1

cleanup
mark_built "$PKG_NAME"
