#!/bin/bash
# LFS 12.4 - 8.48. OpenSSL-3.5.2
source "/scripts/lib/common.sh"
PKG_NAME="openssl"
check_built "$PKG_NAME" && exit 0
extract "openssl"

./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic

make $MAKEFLAGS

sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install

mv -v /usr/share/doc/openssl /usr/share/doc/openssl-3.5.2

cd .. && rm -rf "openssl-"*
mark_built "$PKG_NAME"
