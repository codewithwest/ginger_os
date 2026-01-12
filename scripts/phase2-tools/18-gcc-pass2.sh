#!/bin/bash
# LFS 12.2 - 6.18. GCC-14.2.0 - Pass 2
# Complete the cross-compiler construction.

source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="gcc-pass2"
PKG_VERSION="$GCC_VERSION"
ARCHIVE="gcc-$GCC_VERSION.tar.xz"
DIR_NAME="gcc-$GCC_VERSION"

check_built "$PKG_NAME" && exit 0

extract "$ARCHIVE" "$DIR_NAME"

# Extract dependencies
log "PROCESS" "Extracting GCC dependencies..."
tar -xf "$GINGER_SOURCES/gmp-$GMP_VERSION.tar.xz" && mv -v gmp-$GMP_VERSION gmp
tar -xf "$GINGER_SOURCES/mpfr-$MPFR_VERSION.tar.xz" && mv -v mpfr-$MPFR_VERSION mpfr
tar -xf "$GINGER_SOURCES/mpc-$MPC_VERSION.tar.gz" && mv -v mpc-$MPC_VERSION mpc

case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
  ;;
esac

sed '/thread_header =/s/@.*@/gthr-posix.h/' \
    -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in

mkdir -v build
cd build

../configure                                       \
    --build=$(../config.guess)                     \
    --host=$LFS_TGT                                \
    --target=$LFS_TGT                              \
    --prefix=/usr                                  \
    --enable-default-pie                           \
    --enable-default-ssp                           \
    --disable-nls                                  \
    --with-sysroot                                 \
    --enable-languages=c,c++                       \
    --enable-libstdcxx-time                        \
    --enable-threads=posix                         \
    --disable-multilib                             \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx-pch                        \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/$GCC_VERSION

make $MAKEFLAGS
make DESTDIR=$LFS install

# Create symlink for compatibility
ln -sv gcc $LFS/usr/bin/cc

cd ../..
rm -rf "$DIR_NAME"

mark_built "$PKG_NAME"
