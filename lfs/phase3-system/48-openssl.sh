#!/bin/bash
# LFS 13.0  - 8.48. OpenSSL-3.5.2
source "/lfs/lib/common.sh"
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

mv -v /usr/share/doc/openssl /usr/share/doc/openssl-${OPENSSL_VERSION}

cleanup
mark_built "$PKG_NAME"
