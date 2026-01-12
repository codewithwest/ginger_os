#!/bin/bash
# LFS 12.4 - 8.82. E2fsprogs-1.47.3
source "/scripts/common.sh"
PKG_NAME="e2fsprogs"
ARCHIVE="e2fsprogs-1.47.3.tar.gz"
DIR_NAME="e2fsprogs-1.47.3"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
mkdir -v build
cd build
../configure --prefix=/usr           \
             --sysconfdir=/etc       \
             --enable-elf-shlibs     \
             --disable-libblkid      \
             --disable-libuuid       \
             --disable-uuidd         \
             --disable-fsck
make $MAKEFLAGS
make install
rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
cd ../.. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
