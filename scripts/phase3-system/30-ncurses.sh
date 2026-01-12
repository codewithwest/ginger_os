#!/bin/bash
# LFS 12.4 - 8.30. Ncurses-6.5
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="ncurses"
check_built "$PKG_NAME" && exit 0
extract "ncurses"

./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-ada           \
            --enable-widec          \
            --with-is_term_type

make $MAKEFLAGS
make DESTDIR=$PWD/dest install
install -vm755 dest/usr/lib/libncursesw.so.6.5 /usr/lib
rm -v  dest/usr/lib/libncursesw.so.6.5
sed -e 's/^#bold/bold/' -i dest/usr/lib/pkgconfig/ncursesw.pc
cp -av dest/* /

for lib in ncurses form panel menu ; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv lib${lib}w.a /usr/lib/lib${lib}.a
    ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
done
ln -sfv libncursesw.so /usr/lib/libcurses.so

cd .. && rm -rf "ncurses-"*
mark_built "$PKG_NAME"
