#!/bin/bash
# LFS 12.4 - 8.41. Inetutils-2.6
source "/scripts/common.sh"
PKG_NAME="inetutils"
check_built "$PKG_NAME" && exit 0
extract "inetutils"
# Handle GCC 15 strictness for legacy terminal functions
sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c

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

mv -v /usr/{,s}bin/ifconfig


# In Merged-usr, ifconfig/ping etc are already in /usr/bin. 
# We just need to ensure permissions are correct if needed.

cd .. && rm -rf "inetutils-"*
mark_built "$PKG_NAME"
