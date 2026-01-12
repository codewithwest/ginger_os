#!/bin/bash
# LFS 12.4 - 6.3. Ncurses-6.5
source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="ncurses-temp"
check_built "$PKG_NAME" && exit 0

extract "ncurses"

log "PROCESS" "Compiling Ncurses (Temporary Tools)..."

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
rm -rf "ncurses"*

mark_built "$PKG_NAME"
