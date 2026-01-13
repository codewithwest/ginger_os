#!/bin/bash
# LFS 12.4 - 6.5. Coreutils-9.7
source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="coreutils-temp"
check_built "$PKG_NAME" && exit 0

extract "coreutils"

./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime

make $MAKEFLAGS
make DESTDIR=$LFS install

mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8

cd .. && rm -rf "coreutils-"*
mark_built "$PKG_NAME"
