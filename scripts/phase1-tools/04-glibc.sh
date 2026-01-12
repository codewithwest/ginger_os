#!/bin/bash
# LFS 12.4 - 5.5. Glibc-2.42
source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="glibc"
check_built "$PKG_NAME" && exit 0

extract "glibc"

log "PROCESS" "Compiling Glibc..."

# Create compatibility symlink
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3 ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3 ;;
esac

# FHS patch (if present)
if [ -f "$GINGER_SOURCES/glibc-2.42-fhs-1.patch" ]; then
    patch -Np1 -i "$GINGER_SOURCES/glibc-2.42-fhs-1.patch"
fi

mkdir -v build
cd build

echo "rootsbindir=/usr/sbin" > configparms

../configure --prefix=/usr                      \
             --host=$LFS_TGT                    \
             --build=$(../scripts/config.guess) \
             --enable-kernel=4.19               \
             --with-headers=$LFS/usr/include    \
             --disable-nscd                     \
             libc_cv_slibdir=/usr/lib

make $MAKEFLAGS
make DESTDIR=$LFS install

# Fix ldd path
sed -i 's|/usr/bin/perl|/usr/bin/env perl|' $LFS/usr/bin/ldd

cd ../..
rm -rf "glibc-"*

mark_built "$PKG_NAME"
