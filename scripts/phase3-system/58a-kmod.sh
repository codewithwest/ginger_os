#!/bin/bash
# LFS 12.4 - 8.58a. Kmod-34.2

source "/scripts/common.sh"
PKG_NAME="kmod"
check_built "$PKG_NAME" && exit 0
extract "kmod"

mkdir -p build
cd       build

meson setup --prefix=/usr ..    \
            --buildtype=release \
            -D manpages=false

ninja

ninja install

cd .. && rm -rf "kmod-"*
mark_built "$PKG_NAME"
