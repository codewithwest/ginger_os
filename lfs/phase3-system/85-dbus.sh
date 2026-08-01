#!/bin/bash
# LFS 13.0 - D-Bus-1.16.2
source "/lfs/lib/common.sh"
PKG_NAME="dbus"
check_built "$PKG_NAME" && exit 0
extract "dbus"

mkdir build
cd    build

meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback \
            -D libdir=/usr/lib ..

ninja
ninja install

ln -sfv /etc/machine-id /var/lib/dbus

cd .. && cleanup
mark_built "$PKG_NAME"
