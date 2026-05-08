#!/bin/bash
# LFS 12.4 - 8.82. E2fsprogs-1.47.2
source "/scripts/lib/common.sh"
PKG_NAME="e2fsprogs"
check_built "$PKG_NAME" && exit 0
extract "e2fsprogs"

mkdir -v build
cd build

../configure --prefix=/usr       \
             --sysconfdir=/etc   \
             --enable-elf-shlibs \
             --disable-libblkid  \
             --disable-libuuid   \
             --disable-uuidd     \
             --disable-fsck

make $MAKEFLAGS
make install

rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a

gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info

sed 's/metadata_csum_seed,//' -i /etc/mke2fs.conf

cd ../.. && cleanup
mark_built "$PKG_NAME"
# Note: Root required for some e2fsprogs steps.
