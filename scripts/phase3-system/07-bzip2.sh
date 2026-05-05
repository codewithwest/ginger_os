#!/bin/bash
# LFS 12.4 - 8.7. Bzip2-1.0.8
source "/scripts/lib/common.sh"
PKG_NAME="bzip2"
check_built "$PKG_NAME" && exit 0
extract "bzip2"

# Apply documentation patch if present
patch -Np1 -i /sources/bzip2-1.0.8-install_docs-1.patch

sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile

sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile


make -f Makefile-libbz2_so
make clean

make $MAKEFLAGS
make PREFIX=/usr install

cp -av libbz2.so.* /usr/lib
ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so

cp -v bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do
  ln -sfv bzip2 $i
done

rm -fv /usr/lib/libbz2.a

cleanup
mark_built "$PKG_NAME"
