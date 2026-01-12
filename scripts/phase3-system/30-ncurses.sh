#!/bin/bash
# LFS 12.4 - 8.30. Ncurses-6.5
source "/scripts/common.sh"
PKG_NAME="ncurses"
ARCHIVE="ncurses-6.5-20250809.tar.gz"
DIR_NAME="ncurses-6.5-20250809"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-ada           \
            --with-terminfo-dirs="/etc/terminfo:/usr/share/terminfo" \
            --enable-widec          \
            --with-pkg-config-libdir=/usr/lib/pkgconfig
make $MAKEFLAGS
make DESTDIR=$LFS install # Note: DESTDIR used if run before chroot, but here we are in chroot
make install
ln -svw libncursesw.so /usr/lib/libncurses.so
for lib in ncurses form panel menu ; do
    rm -vf                    /usr/lib/lib${lib}.so
    echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
done
rm -vf                     /usr/lib/libcursesw.so
echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
ln -sfv libncurses.so      /usr/lib/libcurses.so
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
