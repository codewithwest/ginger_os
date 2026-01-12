#!/bin/bash
# LFS 12.4 - 8.65. GRUB-2.12
source "/scripts/common.sh"
PKG_NAME="grub"
ARCHIVE="grub-2.12.tar.xz"
DIR_NAME="grub-2.12"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
unset {C,CPP,CXX,LD}FLAGS
echo "DEPENDS font-unicode" > grub-core/Makefile.core.def
./configure --prefix=/usr          \
            --sysconfdir=/etc      \
            --disable-efiemu       \
            --disable-werror
make $MAKEFLAGS
make install
mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
