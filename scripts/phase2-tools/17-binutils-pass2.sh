#!/bin/bash
# LFS 12.2 - 6.17. Binutils-2.43.1 - Pass 2
# Second pass to create a native toolchain for the chroot environment.

source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="binutils-pass2"
PKG_VERSION="$BINUTILS_VERSION"
ARCHIVE="binutils-$BINUTILS_VERSION.tar.xz"
DIR_NAME="binutils-$BINUTILS_VERSION"

check_built "$PKG_NAME" && exit 0

extract "$ARCHIVE" "$DIR_NAME"

log "PROCESS" "Compiling Binutils Pass 2..."

sed '6009s/$add_dir//' -i ltmain.sh

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
    --enable-64-bit-bfd

make $MAKEFLAGS
make DESTDIR=$LFS install

# Clean up libtool files
rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.la

cd ../..
rm -rf "$DIR_NAME"

mark_built "$PKG_NAME"
