#!/bin/bash
# LFS 12.4 - 8.30. Ncurses-6.5
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="ncurses"
check_built "$PKG_NAME" && exit 0
extract "ncurses"

# 1. Configure
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-ada           \
            --enable-widec          \
            --with-is_term_type

# 2. Build & Install
make $MAKEFLAGS

# Install to a temporary directory first as per LFS book recommendation for some files
make DESTDIR=$PWD/dest install

# Install the library to the real system
install -vm755 dest/usr/lib/libncursesw.so.6.5 /usr/lib
rm -v  dest/usr/lib/libncursesw.so.6.5

# Fix pkg-config file
sed -e 's/^#bold/bold/' -i dest/usr/lib/pkgconfig/ncursesw.pc
cp -av dest/* /

# 3. Handle Wide-Character Compatibility Symlinks
# Many applications expect non-wide character libraries.
# We trick them into using the wide-character ones.
for lib in ncurses form panel menu ; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
done

# Old applications looking for -lcurses
ln -sfv libncursesw.so /usr/lib/libcurses.so

# 4. Install Documentation
mkdir -pv /usr/share/doc/ncurses-6.5
cp -v -R doc/* /usr/share/doc/ncurses-6.5

# 5. Optional: Ncurses 5 Compatibility (LSB/Binary compatibility)
# This builds the older ABI version 5 shared libraries for legacy support.
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
