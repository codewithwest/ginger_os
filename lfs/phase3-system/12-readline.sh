#!/bin/bash
# LFS 12.4 - 8.12. Readline-8.3
source "/lfs/lib/common.sh"
PKG_NAME="readline"
check_built "$PKG_NAME" && exit 0
extract "readline"

sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install

sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf

./configure --prefix=/usr    \
            --disable-static \
            --with-curses    \
            --docdir=/usr/share/doc/readline-8.3

make SHLIB_LIBS="-lncursesw" $MAKEFLAGS
make SHLIB_LIBS="-lncursesw" install

install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.3

cleanup
mark_built "$PKG_NAME"
