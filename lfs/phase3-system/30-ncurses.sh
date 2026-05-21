#!/bin/bash
# LFS 13.0  - 8.30. Ncurses-6.5
source "/lfs/lib/common.sh"
PKG_NAME="ncurses"
check_built "$PKG_NAME" && exit 0
extract "ncurses"

# 1. Fix GCC 15 compatibility: Prevent ncurses from redefining 'bool' as 'unsigned char'
# which causes conflicts with libstdc++ template specializations.
# sed -i 's/typedef unsigned char NCURSES_BOOL/typedef bool NCURSES_BOOL/' include/curses.h.in

# 2. Configure for Wide-Character support (Mandatory for LFS 13.0)
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-normal        \
            --with-cxx-shared       \
            --enable-pc-files       \
            --with-pkg-config-libdir=/usr/lib/pkgconfig


# 2. Build & Install
make $MAKEFLAGS

# Install to a temporary directory first as per LFS book

make DESTDIR=$PWD/dest install
sed -e 's/^#if.*XOPEN.*$/#if 1/' \
    -i dest/usr/include/curses.h
cp --remove-destination -av dest/* /


for lib in ncurses form panel menu ; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
done

# Old applications looking for -lcurses
ln -sfv libncursesw.so /usr/lib/libcurses.so

# 4. Optional: Ncurses 5 Compatibility (Legacy Support)
log "INFO" "Building Ncurses 5 compatibility libraries..."
make distclean
./configure --prefix=/usr    \
            --with-shared    \
            --without-normal \
            --without-debug  \
            --without-cxx-binding \
            --with-abi-version=5
            
make sources libs
cp -av lib/lib*.so.5* /usr/lib

cleanup
mark_built "$PKG_NAME"
