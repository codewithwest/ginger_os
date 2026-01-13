#!/bin/bash
# LFS 12.4 - 8.68. Kbd-2.8.0
source "/scripts/common.sh"
PKG_NAME="kbd"
check_built "$PKG_NAME" && exit 0
extract "kbd"

# Apply backspace patch
patch -Np1 -i ../kbd-2.8.0-backspace-1.patch

sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in

./configure --prefix=/usr --disable-vlock

make $MAKEFLAGS
make install

cp -R -v docs/doc -T /usr/share/doc/kbd-2.8.0

cd .. && rm -rf "kbd-"*
mark_built "$PKG_NAME"
