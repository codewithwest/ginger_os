#!/bin/bash
# LFS 12.4 - Libburn-1.5.6
source "/scripts/common.sh"
PKG_NAME="libburn"

check_built "$PKG_NAME" && exit 0
extract "libburn"

sed -i 's/catch_int ()/catch_int (int signum)/' test/poll.c


./configure --prefix=/usr --disable-static &&

make $MAKEFLAGS
make install

cd .. && rm -rf "libburn-"*
mark_built "$PKG_NAME"
