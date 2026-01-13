#!/bin/bash
# LFS 12.4 - 6.9. Gawk-5.3.1
source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="gawk-temp"
check_built "$PKG_NAME" && exit 0

extract "gawk"

sed -i 's/extras//' Makefile.in

./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

make $MAKEFLAGS
make DESTDIR=$LFS install

cd ..
rm -rf "gawk-"*

mark_built "$PKG_NAME"
