#!/bin/bash
# LFS 13.0  - 8.81. Util-linux-2.41.1
source "/lfs/lib/common.sh"
PKG_NAME="util-linux"
check_built "$PKG_NAME" && exit 0
extract "util-linux"

./configure --bindir=/usr/bin     \
            --libdir=/usr/lib     \
            --runstatedir=/run    \
            --sbindir=/usr/sbin   \
            --disable-chfn-chsh   \
            --disable-login       \
            --disable-nologin     \
            --disable-su          \
            --disable-setpriv     \
            --disable-runuser     \
            --disable-pylibmount  \
            --disable-liblastlog2 \
            --disable-static      \
            --without-python      \
            --without-systemd     \
            --without-systemdsystemunitdir        \
            ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --docdir=/usr/share/doc/util-linux-2.41.1
            
make $MAKEFLAGS
make install
cleanup
mark_built "$PKG_NAME"
