#!/bin/bash
# LFS 12.4 - 8.31. Sed-4.9
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"
PKG_NAME="sed"
check_built "$PKG_NAME" && exit 0
extract "sed"

./configure --prefix=/usr

make $MAKEFLAGS

make html

make install
make install-html

install -d -m755           /usr/share/doc/sed-4.9
install -m644 doc/sed.html /usr/share/doc/sed-4.9

cd .. && rm -rf "sed-"*
mark_built "$PKG_NAME"
