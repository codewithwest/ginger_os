#!/bin/bash
# LFS 12.4 - 8.68. Kbd-2.8.0
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"
PKG_NAME="kbd"
check_built "$PKG_NAME" && exit 0
extract "kbd"

# Apply backspace patch
if [ -f "$GINGER_SOURCES/kbd-2.8.0-backspace-1.patch" ]; then
    patch -Np1 -i "$GINGER_SOURCES/kbd-2.8.0-backspace-1.patch"
fi

sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure
sed -i 's/\(MESON_PROGS=\)yes/\1no/g' configure

./configure --prefix=/usr --disable-vlock
make $MAKEFLAGS
make install

cd .. && rm -rf "kbd-"*
mark_built "$PKG_NAME"
