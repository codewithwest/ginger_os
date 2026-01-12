#!/bin/bash
# LFS 12.4 - 8.59. Coreutils-9.7
source "/scripts/common.sh"
PKG_NAME="coreutils-final"
ARCHIVE="coreutils-9.7.tar.xz"
DIR_NAME="coreutils-9.7"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
patch -Np1 -i /sources/coreutils-9.7-i18n-1.patch
autoreconf -fiv # Required after i18n patch
FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr             \
            --enable-no-install-program=kill,uptime
make $MAKEFLAGS
make install
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
