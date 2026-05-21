#!/bin/bash
# LFS 13.0  - 8.18. DejaGNU-1.6.3
source "/lfs/lib/common.sh"
PKG_NAME="dejagnu"
check_built "$PKG_NAME" && exit 0
extract "dejagnu"

mkdir -v build
cd       build

../configure --prefix=/usr
makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi

# make $MAKEFLAGS

make install
install -v -dm755  /usr/share/doc/dejagnu-${DEJAGNU_VERSION}
install -v -m644   doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-${DEJAGNU_VERSION}

cleanup
mark_built "$PKG_NAME"
