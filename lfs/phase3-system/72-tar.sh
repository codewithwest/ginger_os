#!/bin/bash
# LFS 12.4 - 8.72. Tar-1.35
source "/lfs/lib/common.sh"
PKG_NAME="tar"
check_built "$PKG_NAME" && exit 0
extract "tar"

FORCE_UNSAFE_CONFIGURE=1  \
./configure --prefix=/usr

make $MAKEFLAGS
make install

make -C doc install-html docdir=/usr/share/doc/tar-1.35


cleanup
mark_built "$PKG_NAME"
