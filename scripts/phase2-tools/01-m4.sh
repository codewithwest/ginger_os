#!/bin/bash
# LFS 12.4 - 6.2. M4-1.4.20
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

PKG_NAME="m4-temp"
check_built "$PKG_NAME" && exit 0

# Clean start for M4
rm -rf "$GINGER_ROOT/build/m4-"*

extract "m4"

log "PROCESS" "Compiling M4 (Temporary Tools)..."

# check for 
# Some modern hosts need these extra flags for GNULIB safety
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

make $MAKEFLAGS
make DESTDIR=$LFS install

cd ..
rm -rf "m4-"*

mark_built "$PKG_NAME"
