#!/bin/bash
# LFS 12.4 - 8.41. Inetutils-2.6
source "/scripts/common.sh"
PKG_NAME="inetutils"
ARCHIVE="inetutils-2.6.tar.xz"
DIR_NAME="inetutils-2.6"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr        \
            --bindir=/usr/bin    \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --make-install-do-conf-install
make $MAKEFLAGS
make install
mv -v /usr/sbin/ifconfig /usr/bin
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
