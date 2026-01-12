#!/bin/bash
# LFS 12.4 - 8.39. Gperf-3.3
source "/scripts/common.sh"
PKG_NAME="gperf"
ARCHIVE="gperf-3.3.tar.gz"
DIR_NAME="gperf-3.3"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
