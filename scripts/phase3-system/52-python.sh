#!/bin/bash
# LFS 12.4 - 8.52. Python-3.13.7
source "/scripts/common.sh"
PKG_NAME="Python"
check_built "$PKG_NAME" && exit 0
extract "Python"

./configure --prefix=/usr          \
            --enable-shared        \
            --with-system-expat    \
            --enable-optimizations \
            --without-static-libpython


make $MAKEFLAGS
make install

cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF



cd .. && rm -rf "Python-"*
mark_built "$PKG_NAME"
