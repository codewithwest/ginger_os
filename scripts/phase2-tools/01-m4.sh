#!/bin/bash
# LFS 12.4 - 6.2. M4-1.4.20
source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="m4-temp"
check_built "$PKG_NAME" && exit 0

extract "m4"

log "PROCESS" "Compiling M4 (Temporary Tools)..."

./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

make $MAKEFLAGS
make DESTDIR=$LFS install

cd ..
rm -rf "m4-"*

mark_built "$PKG_NAME"
