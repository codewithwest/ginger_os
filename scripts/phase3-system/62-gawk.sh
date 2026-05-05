#!/bin/bash
# LFS 12.4 - 8.62. Gawk-5.3.1
source "/scripts/lib/common.sh"
PKG_NAME="gawk"
check_built "$PKG_NAME" && exit 0
extract "gawk"

sed -i 's/extras//' Makefile.in

./configure --prefix=/usr
make $MAKEFLAGS

rm -f /usr/bin/gawk-5.3.2
make install

ln -sfv gawk.1 /usr/share/man/man1/awk.1

install -vDm644 doc/{awkforai.txt,*.{eps,pdf,jpg}} -t /usr/share/doc/gawk-5.3.2


cleanup
mark_built "$PKG_NAME"
