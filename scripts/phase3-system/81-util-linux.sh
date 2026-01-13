#!/bin/bash
# LFS 12.4 - 8.81. Util-linux-2.41.1
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"
PKG_NAME="util-linux"
check_built "$PKG_NAME" && exit 0
extract "util-linux"
./configure --bindir=/usr/bin    \
            --libdir=/usr/lib    \
            --runstatedir=/run   \
            --sbindir=/usr/sbin  \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-python     \
            --docdir=/usr/share/doc/util-linux-2.41.1
make $MAKEFLAGS
make install
cd .. && rm -rf "util-linux-"*
mark_built "$PKG_NAME"
