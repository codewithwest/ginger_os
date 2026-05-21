#!/bin/bash
# LFS 13.0  - 8.59. Coreutils-9.7
source "/lfs/lib/common.sh"
PKG_NAME="coreutils"
check_built "$PKG_NAME" && exit 0
extract "coreutils"

# Patch for internationalization
apply_patch "coreutils" "upstream_fix"
apply_patch "coreutils" "i18n"



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

cleanup
mark_built "$PKG_NAME"
# Note: Root user required for some coreutils install steps.
