#!/bin/bash
# LFS 12.4 - 8.59. Coreutils-9.7
source "/scripts/common.sh"
PKG_NAME="coreutils"
check_built "$PKG_NAME" && exit 0
extract "coreutils"

# Patch for internationalization
patch -Np1 -i /sources/coreutils-9.7-upstream_fix-1.patch

patch -Np1 -i /sources/coreutils-9.7-i18n-1.patch



autoreconf -fv
automake -af
FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr            \
            --enable-no-install-program=kill,uptime

make $MAKEFLAGS
make install

mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8

cd .. && rm -rf "coreutils-"*
mark_built "$PKG_NAME"
# Note: Root user required for some coreutils install steps.
