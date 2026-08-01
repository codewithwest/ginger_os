#!/bin/bash
# LFS 13.0  - 8.31. Sed-4.9
source "/lfs/lib/common.sh"
PKG_NAME="sed"
check_built "$PKG_NAME" && exit 0
extract "sed"

./configure --prefix=/usr

make $MAKEFLAGS

make html

make install
make install-html

install -d -m755           /usr/share/doc/sed-${SED_VERSION}
install -m644 doc/sed.html /usr/share/doc/sed-${SED_VERSION}

cleanup
mark_built "$PKG_NAME"
