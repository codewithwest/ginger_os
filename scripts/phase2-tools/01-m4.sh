#!/bin/bash
# LFS 12.2 - 6.2. M4-1.4.19
# A macro processor required for building many other packages.

source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="m4-temp"
PKG_VERSION="1.4.19"
ARCHIVE="m4-1.4.19.tar.xz"
DIR_NAME="m4-1.4.19"

check_built "$PKG_NAME" && exit 0

extract "$ARCHIVE" "$DIR_NAME"

log "PROCESS" "Compiling M4..."

./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

make $MAKEFLAGS
make DESTDIR=$LFS install

cd ..
rm -rf "$DIR_NAME"

mark_built "$PKG_NAME"
