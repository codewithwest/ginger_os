#!/bin/bash
# LFS 13.0  - 8.52. Python-3.13.7
source "/lfs/lib/common.sh"
PKG_NAME="newPythonPip"
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

cleanup
mark_built "$PKG_NAME"
