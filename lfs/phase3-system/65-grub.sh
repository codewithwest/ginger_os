#!/bin/bash
source "/lfs/lib/common.sh"
PKG_NAME="grub"
check_built "$PKG_NAME" && exit 0
extract "grub"

unset {C,CPP,CXX,LD}FLAGS

sed 's/--image-base/--nonexist-linker-option/' -i configure

echo depends bli part_gpt > grub-core/extra_deps.lst

./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --disable-efiemu  \
            --disable-werror

make
make install

cleanup
mark_built "$PKG_NAME"
