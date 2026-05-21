#!/bin/bash
# LFS 13.0  - 7.7. Gettext-0.23.1 (Temporary)
source "/lfs/lib/common.sh"
PKG_NAME="gettext-bridge"
check_built "$PKG_NAME" && exit 0
extract "gettext"

./configure --disable-shared

make $MAKEFLAGS
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin

cleanup
mark_built "$PKG_NAME"
