#!/bin/bash
# LFS 12.4 - Libisoburn-1.5.6 (xorriso)
source "/scripts/common.sh"
PKG_NAME="libisoburn"

check_built "$PKG_NAME" && exit 0
extract "libisoburn"

./configure --prefix=/usr              \
            --disable-static           \
            --enable-pkg-check-modules
make $MAKEFLAGS
make install

# Install documentation if needed (skipping for minimal build, but following instructions)
install -v -dm755 /usr/share/doc/libisoburn-$LIBISOBURN_VERSION
if [ -d doc/html ]; then
    install -v -m644 doc/html/* /usr/share/doc/libisoburn-$LIBISOBURN_VERSION
fi

cd .. && rm -rf "libisoburn-"*
mark_built "$PKG_NAME"
