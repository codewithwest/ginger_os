#!/bin/bash
# LFS 12.4 - 6.15. Tar-1.35
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

PKG_NAME="tar-temp"
check_built "$PKG_NAME" && exit 0

extract "tar"

./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess)

make $MAKEFLAGS
make DESTDIR=$LFS install

cd ..
rm -rf "tar-"*

mark_built "$PKG_NAME"
