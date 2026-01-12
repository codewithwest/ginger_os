#!/bin/bash
# LFS 12.4 - 8.7. Bzip2-1.0.8
source "/scripts/common.sh"
PKG_NAME="bzip2"
ARCHIVE="bzip2-1.0.8.tar.gz"
DIR_NAME="bzip2-1.0.8"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
patch -Np1 -i /sources/bzip2-1.0.8-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
make -f Makefile-libbz2_so
make clean
make $MAKEFLAGS
make PREFIX=/usr install
cp -av libbz2.so.* /usr/lib
ln -sv libbz2.so.1.0.8 /usr/lib/libbz2.so
cp -v bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do
  ln -sfv bzip2 $i
done
rm -fv /usr/lib/libbz2.a
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
