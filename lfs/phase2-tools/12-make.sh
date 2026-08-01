#!/bin/bash
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

PKG_NAME="make-temp"
check_built "$PKG_NAME" && exit 0

extract "make"

./configure --prefix=/usr   \
            --without-guile \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

make $MAKEFLAGS
make DESTDIR=$LFS install

cd ..
cleanup

mark_built "$PKG_NAME"
