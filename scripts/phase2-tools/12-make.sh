#!/bin/bash
# LFS 12.4 - 6.12. Make-4.4.1
source "$(dirname "$(readlink -f "$0")")/../common.sh"

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
rm -rf "make-"*

mark_built "$PKG_NAME"
