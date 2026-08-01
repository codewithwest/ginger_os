#!/bin/bash
# LFS 13.0  - 8.58a. Kmod-34.2

source "/lfs/lib/common.sh"
PKG_NAME="kmod"
check_built "$PKG_NAME" && exit 0
extract "kmod"

mkdir -p build
cd       build

meson setup --prefix=/usr ..    \
            --buildtype=release \
            -D manpages=false   \
            -D libdir=/usr/lib

ninja

ninja install

cleanup
mark_built "$PKG_NAME"
