#!/bin/bash
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

PKG_NAME="xz-temp"
check_built "$PKG_NAME" && exit 0

extract "xz"

./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --disable-static                  \
            --docdir=/usr/share/doc/xz-${XZ_VERSION}

make $MAKEFLAGS
make DESTDIR=$LFS install

rm -v $LFS/usr/lib/liblzma.la

cd ..
cleanup

mark_built "$PKG_NAME"
