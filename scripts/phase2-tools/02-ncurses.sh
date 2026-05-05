#!/bin/bash
# LFS 12.4 - 6.3. Ncurses-6.5
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

PKG_NAME="ncurses-temp"
check_built "$PKG_NAME" && exit 0

extract "ncurses"

log "PROCESS" "Compiling Ncurses (Temporary Tools)..."

# Ensure tic is built on the host
# sed -i s/mawk// configure

mkdir build

pushd build
  ../configure --prefix=$LFS/tools AWK=gawk
  make -C include
  make -C progs tic
  install progs/tic $LFS/tools/bin
popd

./configure --prefix=/usr                \
            --host=$LFS_TGT              \
            --build=$(./config.guess)    \
            --mandir=/usr/share/man      \
            --with-manpage-format=normal \
            --with-shared                \
            --without-normal             \
            --without-cxx-binding        \
            --without-debug              \
            --without-ada                \
            --disable-stripping          \
            AWK=gawk

make $MAKEFLAGS

make DESTDIR=$LFS install
ln -sfv libncursesw.so $LFS/usr/lib/libncurses.so
sed -e 's/^#if.*XOPEN.*$/#if 1/' \
    -i $LFS/usr/include/curses.h

cd ..
rm -rf "ncurses"*

mark_built "$PKG_NAME"
