#!/bin/bash
# LFS 12.4 - 6.8. Findutils-4.10.0
source "$(dirname "$(readlink -f "$0")")/common.sh"

PKG_NAME="findutils-temp"
check_built "$PKG_NAME" && exit 0

extract "findutils"

./configure --prefix=/usr                   \
            --localstatedir=/var/lib/locate \
            --host=$LFS_TGT                 \
            --build=$(build-aux/config.guess)

make $MAKEFLAGS
make DESTDIR=$LFS install

cd ..
rm -rf "findutils-"*

mark_built "$PKG_NAME"
