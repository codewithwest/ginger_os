#!/bin/bash
# LFS 12.4 - 8.48. OpenSSL-3.5.2
source "/scripts/common.sh"
PKG_NAME="openssl"
ARCHIVE="openssl-3.5.2.tar.gz"
DIR_NAME="openssl-3.5.2"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic
make $MAKEFLAGS
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
mv -v /usr/share/doc/openssl /usr/share/doc/openssl-3.5.2
cp -vfr doc/* /usr/share/doc/openssl-3.5.2
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
