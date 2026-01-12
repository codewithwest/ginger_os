#!/bin/bash
# LFS 12.4 - 8.49. Kmod-34.2
source "/scripts/common.sh"
PKG_NAME="kmod"
ARCHIVE="kmod-34.2.tar.xz"
DIR_NAME="kmod-34.2"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr          \
            --sysconfdir=/etc      \
            --with-openssl         \
            --with-xz              \
            --with-zstd            \
            --with-zlib
make $MAKEFLAGS
make install
for target in depmod insmod modinfo modprobe rmmod; do
  ln -sfv ../bin/kmod /usr/sbin/$target
done
ln -sfv kmod /usr/bin/lsmod
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
