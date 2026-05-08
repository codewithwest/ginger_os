#!/bin/bash
# LFS 12.4 - 6.4. Bash-5.3
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

PKG_NAME="bash-temp"
check_built "$PKG_NAME" && exit 0

extract "bash"

log "PROCESS" "Compiling Bash (Temporary Tools)..."

./configure --prefix=/usr                      \
            --build=$(sh support/config.guess) \
            --host=$LFS_TGT                    \
            --without-bash-malloc

make $MAKEFLAGS
make DESTDIR=$LFS install

# LFS 12.4: Create the sh symlink
ln -sfv bash $LFS/bin/sh

cd ..
cleanup

mark_built "$PKG_NAME"
