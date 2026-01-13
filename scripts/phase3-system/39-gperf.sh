#!/bin/bash
# LFS 12.4 - 8.39. Gperf-3.3
source "/scripts/common.sh"
PKG_NAME="gperf"
check_built "$PKG_NAME" && exit 0
extract "gperf"

./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3
make $MAKEFLAGS
make install

cd .. && rm -rf "gperf-"*
mark_built "$PKG_NAME"
