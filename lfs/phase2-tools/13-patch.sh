#!/bin/bash
# LFS 12.4 - 6.13. Patch-2.8
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

PKG_NAME="patch-temp"
check_built "$PKG_NAME" && exit 0

extract "patch"

./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

make $MAKEFLAGS
make DESTDIR=$LFS install

cd ..
cleanup

mark_built "$PKG_NAME"
