#!/bin/bash
# LFS 13.0  - 7.12. Util-linux-2.41.1 (Temporary)
source "/lfs/lib/common.sh"
PKG_NAME="util-linux-bridge"
check_built "$PKG_NAME" && exit 0
extract "util-linux"

mkdir -pv /var/lib/hwclock

./configure --libdir=/usr/lib     \
            --runstatedir=/run    \
            --disable-chfn-chsh   \
            --disable-login       \
            --disable-nologin     \
            --disable-su          \
            --disable-setpriv     \
            --disable-runuser     \
            --disable-pylibmount  \
            --disable-static      \
            --disable-liblastlog2 \
            --without-python      \
            ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --docdir=/usr/share/doc/util-linux-${UTIL_LINUX_VERSION}

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
