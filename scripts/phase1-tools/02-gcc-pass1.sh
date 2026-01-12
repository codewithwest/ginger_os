#!/bin/bash
# LFS 12.2 - 5.3. GCC-14.2.0 - Pass 1
# This first pass prepares the cross-compiler used to build the C library.

source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="gcc-pass1"
PKG_VERSION="$GCC_VERSION"
ARCHIVE="gcc-$GCC_VERSION.tar.xz"
DIR_NAME="gcc-$GCC_VERSION"

check_built "$PKG_NAME" && exit 0

extract "$ARCHIVE" "$DIR_NAME"

# Extract dependencies into gcc source tree as per LFS instructions
log "PROCESS" "Extracting GCC dependencies (GMP, MPFR, MPC)..."
tar -xf "$GINGER_SOURCES/gmp-$GMP_VERSION.tar.xz" && mv -v gmp-$GMP_VERSION gmp
tar -xf "$GINGER_SOURCES/mpfr-$MPFR_VERSION.tar.xz" && mv -v mpfr-$MPFR_VERSION mpfr
tar -xf "$GINGER_SOURCES/mpc-$MPC_VERSION.tar.gz" && mv -v mpc-$MPC_VERSION mpc

# Set the dynamic linker for x86_64
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac

log "PROCESS" "Compiling GCC Pass 1..."

mkdir -v build
cd build

../configure                  \
    --target=$LFS_TGT         \
    --prefix=$LFS/tools       \
    --with-glibc-version=$GLIBC_VERSION \
    --with-sysroot=$LFS       \
    --with-newlib             \
    --without-headers         \
    --enable-default-pie      \
    --enable-default-ssp      \
    --disable-nls             \
    --disable-shared          \
    --disable-multilib        \
    --disable-threads         \
    --disable-libatomic       \
    --disable-libgomp         \
    --disable-libquadmath     \
    --disable-libssp          \
    --disable-libvtv          \
    --disable-libstdcxx       \
    --enable-languages=c,c++

make $MAKEFLAGS
make install

cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h

cd ..
rm -rf "$DIR_NAME"

mark_built "$PKG_NAME"
