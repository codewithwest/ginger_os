#!/bin/bash
# LFS 12.4 - 8.49. Kmod-34.2
source "/scripts/common.sh"
PKG_NAME="kmod"
check_built "$PKG_NAME" && exit 0
extract "kmod"
./configure --prefix=/usr          \
            --sysconfdir=/etc      \
            --with-openssl         \
            --with-xz              \
            --with-zstd            \
            --with-zlib            \
            --disable-manpages
make $MAKEFLAGS
make install

for target in depmod insmod modinfo modprobe rmmod; do
  ln -sfv ../bin/kmod /usr/sbin/$target
done
ln -sfv kmod /usr/bin/lsmod

cd .. && rm -rf "kmod-"*
mark_built "$PKG_NAME"
