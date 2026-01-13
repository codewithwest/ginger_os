#!/bin/bash
# LFS 12.4 - 8.30. Ncurses-6.5
source "$(dirname "$(readlink -f "$0")")/common.sh"
PKG_NAME="ncurses"
check_built "$PKG_NAME" && exit 0
extract "ncurses"

# 1. Configure for Wide-Character support (Mandatory for LFS 12.4)
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-ada           \
            --enable-widec          \
            --with-is_term_type     \
            --enable-pc-files       \
            --with-pkg-config-libdir=/usr/lib/pkgconfig

# 2. Build & Install
make $MAKEFLAGS

# Install to a temporary directory first as per LFS book
mkdir -p dest
make DESTDIR=$PWD/dest install

# Install the library to the real system manually to ensure correct path
install -vm755 dest/usr/lib/libncursesw.so.6.5 /usr/lib
rm -v  dest/usr/lib/libncursesw.so.6.5

# Fix curses.h to always use wide-character ABI
sed -e 's/^#if.*XOPEN.*$/#if 1/' -i dest/usr/include/curses.h

# Robust Merge: Using tar instead of cp -a to avoid symlink/directory conflicts in Merged-usr
log "INFO" "Merging Ncurses into system..."
(cd dest && tar cf - . ) | tar xf - -C /

# 3. Handle Wide-Character Compatibility Symlinks
# These allow non-wide applications to link to the wide-character versions.
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

cd .. && rm -rf "ncurses-"*
mark_built "$PKG_NAME"
