#!/bin/bash
# LFS 12.2 - 6.3. Ncurses-6.5
# Library for text-based user interfaces.

source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="ncurses-temp"
PKG_VERSION="$NCURSES_VERSION"
ARCHIVE="ncurses-$NCURSES_VERSION.tar.gz"
DIR_NAME="ncurses-$NCURSES_VERSION"

check_built "$PKG_NAME" && exit 0

extract "$ARCHIVE" "$DIR_NAME"

log "PROCESS" "Compiling Ncurses..."

# Ensure tic is built on the host
sed -i s/mawk// configure

mkdir build
pushd build
  ../configure
  make -C include
  make -C progs tic
popd

./configure --prefix=/usr                \
            --host=$LFS_TGT              \
            --build=$(./config.guess)    \
            --mandir=/usr/share/man      \
            --with-manpage-format=normal \
            --with-shared                \
            --without-normal             \
            --with-cxx-shared            \
            --without-debug              \
            --without-ada                \
            --disable-stripping          \
            --enable-widec

make $MAKEFLAGS
make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
ln -sv libncursesw.so $LFS/usr/lib/libncurses.so
sed -e 's/^#bold/bold/' -i $LFS/usr/lib/pkgconfig/ncursesw.pc

cd ..
rm -rf "$DIR_NAME"

mark_built "$PKG_NAME"
