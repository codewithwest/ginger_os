#!/bin/bash
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

PKG_NAME="grep-temp"
check_built "$PKG_NAME" && exit 0

extract "grep"

./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

make $MAKEFLAGS
make DESTDIR=$LFS install

cd ..
cleanup

mark_built "$PKG_NAME"
