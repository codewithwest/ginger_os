#!/bin/bash
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

PKG_NAME="binutils-pass2"
check_built "$PKG_NAME" && exit 0

extract "binutils"

log "PROCESS" "Configuring Binutils Pass 2..."

# LFS 13.0  specific fix for libtool
sed '6031s/$add_dir//' -i ltmain.sh

mkdir -v build
cd build

../configure                   \
    --prefix=/usr              \
    --build=$(../config.guess) \
    --host=$LFS_TGT            \
    --disable-nls              \
    --enable-shared            \
    --enable-gprofng=no        \
    --disable-werror           \
    --enable-64-bit-bfd        \
    --enable-new-dtags         \
    --enable-default-hash-style=gnu

log "PROCESS" "Compiling Binutils Pass 2..."
make $MAKEFLAGS

log "PROCESS" "Installing Binutils Pass 2..."
make DESTDIR=$LFS install

# Remove libtool files and static libraries
# Use -f to prevent failure if some are missing
rm -fv $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}

cd ../..
cleanup

mark_built "$PKG_NAME"
