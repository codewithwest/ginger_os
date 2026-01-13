#!/bin/bash
# LFS 12.4 - 6.11. Gzip-1.14
source "$(dirname "$(readlink -f "$0")")/common.sh"

PKG_NAME="gzip-temp"
check_built "$PKG_NAME" && exit 0

extract "gzip"

./configure --prefix=/usr --host=$LFS_TGT
make $MAKEFLAGS
make DESTDIR=$LFS install

cd ..
rm -rf "gzip-"*

mark_built "$PKG_NAME"
