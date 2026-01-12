#!/bin/bash
# LFS 12.4 - 8.41. Inetutils-2.6
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="inetutils"
check_built "$PKG_NAME" && exit 0
extract "inetutils"
./configure --prefix=/usr        \
            --bindir=/usr/bin    \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --disable-servers
make $MAKEFLAGS
make install
mv -v /usr/bin/{hostname,ifconfig,ping,ping6,traceroute} /usr/bin
cd .. && rm -rf "inetutils-"*
mark_built "$PKG_NAME"
