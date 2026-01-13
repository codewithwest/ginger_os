#!/bin/bash
# LFS 12.4 - 5.3. GCC-15.2.0 - Pass 1
source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="gcc-pass1"
check_built "$PKG_NAME" && exit 0

extract "gcc"

log "PROCESS" "Setting up GCC internal dependencies..."
# Extract dependencies into the GCC source directory
tar -xf "$GINGER_SOURCES"/mpfr-*.tar.* && mv -v mpfr-* mpfr
tar -xf "$GINGER_SOURCES"/gmp-*.tar.*  && mv -v gmp-* gmp
tar -xf "$GINGER_SOURCES"/mpc-*.tar.*  && mv -v mpc-* mpc

# Fix case for 64-bit systems
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
  ;;
esac

log "PROCESS" "Configuring GCC Pass 1..."
mkdir -v build
cd build

../configure                  \
    --target=$LFS_TGT         \
    --prefix=$LFS/tools       \
    --with-glibc-version=2.42 \
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

log "PROCESS" "Building and installing GCC Pass 1..."
make $MAKEFLAGS
make install

log "PROCESS" "Finalizing GCC Internal Headers (Fixing MB_LEN_MAX issues)..."
# We must perform this from the source directory, not the build directory
cd ..

# Ensure the destination directory exists (sometimes make install misses the subfolder)
LIMITS_DIR=$(dirname "$($LFS_TGT-gcc -print-libgcc-file-name)")/install-tools/include
mkdir -pv "$LIMITS_DIR"

# Creation of the fixed limits.h
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > "$LIMITS_DIR/limits.h"

log "INFO" "GCC Pass 1 finalized. Header located at: $LIMITS_DIR/limits.h"

cd ..
rm -rf "gcc-"*

mark_built "$PKG_NAME"
