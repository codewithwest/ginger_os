#!/bin/bash
# LFS 12.4 - 6.17. Binutils-2.45 - Pass 2
source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="binutils-pass2"
check_built "$PKG_NAME" && exit 0

extract "binutils"

log "PROCESS" "Compiling Binutils Pass 2..."
mkdir -v build
cd build

sed '6031s/$add_dir//' -i ltmain.sh

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

make $MAKEFLAGS
make DESTDIR=$LFS install

# Remove libtool files
rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}

cd ../..
rm -rf "binutils-"*

mark_built "$PKG_NAME"
