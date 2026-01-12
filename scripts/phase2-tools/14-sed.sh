#!/bin/bash
# LFS 12.4 - 6.14. Sed-4.9
source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="sed-temp"
check_built "$PKG_NAME" && exit 0

extract "sed"

./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

make $MAKEFLAGS
make DESTDIR=$LFS install

cd ..
rm -rf "sed-"*

mark_built "$PKG_NAME"
