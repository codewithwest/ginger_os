#!/bin/bash
# LFS 12.2 - 5.5. Glibc-2.40
# The main C library for the system.

source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="glibc"
PKG_VERSION="$GLIBC_VERSION"
ARCHIVE="glibc-$GLIBC_VERSION.tar.xz"
DIR_NAME="glibc-$GLIBC_VERSION"

check_built "$PKG_NAME" && exit 0

extract "$ARCHIVE" "$DIR_NAME"

# Glibc requires a separate build directory
mkdir -v build
cd build

echo "rootsbindir=/usr/sbin" > configparms

log "PROCESS" "Compiling Glibc..."

../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=4.19               \
      --with-headers=$LFS/usr/include    \
      --disable-nls                      \
      libc_cv_slibdir=/usr/lib

make $MAKEFLAGS
make DESTDIR=$LFS install

# Fix ldd path to look into the cross-compiled environment
sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd

cd ../..
rm -rf "$DIR_NAME"

mark_built "$PKG_NAME"
