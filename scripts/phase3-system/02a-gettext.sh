#!/bin/bash
# LFS 12.4 - 7.7. Gettext-0.23.1 (Temporary)
source "$(dirname "$(readlink -f "$0")")/common.sh"
PKG_NAME="gettext-bridge"
check_built "$PKG_NAME" && exit 0
extract "gettext"

./configure --disable-shared

make $MAKEFLAGS
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin

cd .. && rm -rf "gettext-"*
mark_built "$PKG_NAME"
