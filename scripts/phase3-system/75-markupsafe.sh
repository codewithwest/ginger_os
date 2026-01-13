#!/bin/bash
# LFS 12.4 - 8.75. MarkupSafe-3.0.2
source "$(dirname "$(readlink -f "$0")")/common.sh"
PKG_NAME="markupsafe"
check_built "$PKG_NAME" && exit 0
extract "MarkupSafe"
python3 setup.py build
python3 setup.py install --root dest
cp -rv dest/* /
cd .. && rm -rf "MarkupSafe-"*
mark_built "$PKG_NAME"
