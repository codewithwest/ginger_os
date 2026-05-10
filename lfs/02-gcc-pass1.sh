#!/bin/bash
# LFS 12.4 - 5.3. GCC-15.2.0 - Pass 1
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

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

# CRITICAL: The limits.h file MUST be in include-fixed where the compiler searches
# The compiler does NOT search install-tools/include (verified with gcc -v -E)
# This causes MB_LEN_MAX errors in Phase 2 if placed in the wrong directory
GCC_INCLUDE_DIR=$($LFS_TGT-gcc -print-libgcc-file-name | sed 's/libgcc.a//')include-fixed
mkdir -pv "$GCC_INCLUDE_DIR"

# Creation of the fixed limits.h

cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h

cat gcc/limitx.h gcc/glimits.h gcc/limity.h > "$GCC_INCLUDE_DIR/limits.h"

# Use sed to fix MB_LEN_MAX (replace default 1 with correct 16)
sed -i 's/#define MB_LEN_MAX 1/#define MB_LEN_MAX 16/' "$GCC_INCLUDE_DIR/limits.h"
# Also fix the duplicate location if it exists
if [ -f "$LFS/tools/lib/gcc/x86_64-lfs-linux-gnu/15.2.0/include/limits.h" ]; then
    sed -i 's/#define MB_LEN_MAX 1/#define MB_LEN_MAX 16/' "$LFS/tools/lib/gcc/x86_64-lfs-linux-gnu/15.2.0/include/limits.h"
fi

log "INFO" "GCC Pass 1 finalized. Header located at: $GCC_INCLUDE_DIR/limits.h"

cd ..
cleanup

mark_built "$PKG_NAME"
