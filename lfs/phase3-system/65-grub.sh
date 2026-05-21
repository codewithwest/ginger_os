#!/bin/bash
# LFS 13.0  - 8.65. GRUB-2.12
source "/lfs/lib/common.sh"
PKG_NAME="grub"
check_built "$PKG_NAME" && exit 0
extract "grub"

unset {C,CPP,CXX,LD}FLAGS

echo depends bli part_gpt > grub-core/extra_deps.lst

./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --disable-efiemu  \
            --disable-werror

make $MAKEFLAGS
make install

mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions

cleanup
mark_built "$PKG_NAME"
