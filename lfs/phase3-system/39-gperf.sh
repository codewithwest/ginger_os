#!/bin/bash
# LFS 13.0  - 8.39. Gperf-3.3
source "/lfs/lib/common.sh"
PKG_NAME="gperf"
check_built "$PKG_NAME" && exit 0
extract "gperf"

./configure --prefix=/usr --docdir=/usr/share/doc/gperf-${GPERF_VERSION}
make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
