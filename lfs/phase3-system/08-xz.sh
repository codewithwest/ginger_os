#!/bin/bash
# LFS 12.4 - 8.8. Xz-5.8.1
source "/lfs/lib/common.sh"
PKG_NAME="xz-final"
check_built "$PKG_NAME" && exit 0
extract "xz"

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.8.1


make $MAKEFLAGS
make install
if [ -d "/lib/x86_64-linux-gnu" ]; then
    ln -sfv /usr/lib/liblzma.so.5 /lib/x86_64-linux-gnu/liblzma.so.5
fi

cleanup
mark_built "$PKG_NAME"
