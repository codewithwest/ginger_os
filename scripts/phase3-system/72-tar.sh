#!/bin/bash
# LFS 12.4 - 8.72. Tar-1.35
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"
PKG_NAME="tar"
check_built "$PKG_NAME" && exit 0
extract "tar"
FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "tar-"*
mark_built "$PKG_NAME"
