#!/bin/bash
# LFS 12.4 - 8.52. Python-3.13.7
source "/scripts/common.sh"
PKG_NAME="python"
ARCHIVE="Python-3.13.7.tar.xz"
DIR_NAME="Python-3.13.7"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr        \
            --enable-shared      \
            --with-system-expat  \
            --enable-optimizations
make $MAKEFLAGS
make install
cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
