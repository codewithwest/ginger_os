#!/bin/bash
# LFS 12.4 - 8.36. Bash-5.3
source "/scripts/common.sh"
PKG_NAME="bash"
ARCHIVE="bash-5.3.tar.gz"
DIR_NAME="bash-5.3"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr             \
            --disable-static          \
            --with-installed-readline \
            --docdir=/usr/share/doc/bash-5.3
make $MAKEFLAGS
make install
# Make bash available as /bin/sh via main system logic
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
