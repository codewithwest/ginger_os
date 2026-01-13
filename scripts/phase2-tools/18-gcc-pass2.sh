#!/bin/bash
# LFS 12.4 - 6.18. GCC-15.2.0 - Pass 2
source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="gcc-pass2"
check_built "$PKG_NAME" && exit 0

extract "gcc"

log "PROCESS" "Setting up GCC dependencies..."
tar -xf "$GINGER_SOURCES"/mpfr-*.tar.* && mv -v mpfr-* mpfr
tar -xf "$GINGER_SOURCES"/gmp-*.tar.*  && mv -v gmp-* gmp
tar -xf "$GINGER_SOURCES"/mpc-*.tar.*  && mv -v mpc-* mpc

# Fix case for 64-bit systems
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac

# Create compatibility symlink for fixincludes
sed '/^DL_ITERATE_PHDR_P/s/$/ || 1/' -i libgcc/crtstuff.c

log "PROCESS" "Compiling GCC Pass 2..."
mkdir -v build
cd build

mkdir -pv $LFS_TGT/libgcc
ln -s ../../../libgcc/gthr-posix.h $LFS_TGT/libgcc/gthr.h

../configure --build=$(../config.guess)                  \
             --host=$LFS_TGT                             \
             --target=$LFS_TGT                           \
             LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc   \
             --prefix=/usr                               \
             --with-build-sysroot=$LFS                   \
             --enable-default-pie                        \
             --enable-default-ssp                        \
             --disable-nls                               \
             --disable-multilib                          \
             --disable-libatomic                         \
             --disable-libgomp                           \
             --disable-libquadmath                       \
             --disable-libssp                            \
             --disable-libvtv                            \
             --enable-languages=c,c++

make $MAKEFLAGS
make DESTDIR=$LFS install

ln -sv gcc $LFS/usr/bin/cc

cd ../..
rm -rf "gcc-"*

mark_built "$PKG_NAME"
