#!/bin/bash
# LFS 12.4 - 6.6. Diffutils-3.11
source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="diffutils-temp"
check_built "$PKG_NAME" && exit 0

extract "diffutils"

./configure --prefix=/usr --host=$LFS_TGT --build=$(./build-aux/config.guess)

make $MAKEFLAGS
make DESTDIR=$LFS install

cd ..
rm -rf "diffutils-"*

mark_built "$PKG_NAME"
