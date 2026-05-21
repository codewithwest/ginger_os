#!/bin/bash
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

PKG_NAME="gzip-temp"
check_built "$PKG_NAME" && exit 0

extract "gzip"

./configure --prefix=/usr --host=$LFS_TGT
make $MAKEFLAGS
make DESTDIR=$LFS install

cd ..
cleanup

mark_built "$PKG_NAME"
