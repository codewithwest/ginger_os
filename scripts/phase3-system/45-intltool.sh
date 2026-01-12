#!/bin/bash
# LFS 12.4 - 8.45. Intltool-0.51.0
source "/scripts/common.sh"
PKG_NAME="intltool"
ARCHIVE="intltool-0.51.0.tar.gz"
DIR_NAME="intltool-0.51.0"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
sed -i 's:\\\${:\\\${:\\' intltool-update.in
./configure --prefix=/usr
make $MAKEFLAGS
make install
install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
