#!/bin/bash
# LFS 12.2 - 6.4. Bash-5.2.32
# The primary shell.

source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="bash-temp"
PKG_VERSION="5.3"
ARCHIVE="bash-5.3.tar.gz"
DIR_NAME="bash-5.3"

check_built "$PKG_NAME" && exit 0

extract "$ARCHIVE" "$DIR_NAME"

log "PROCESS" "Compiling Bash..."

./configure --prefix=/usr                      \
            --build=$(sh support/config.guess) \
            --host=$LFS_TGT                    \
            --without-bash-malloc

make $MAKEFLAGS
make DESTDIR=$LFS install
ln -sv bash $LFS/bin/sh

cd ..
rm -rf "$DIR_NAME"

mark_built "$PKG_NAME"
