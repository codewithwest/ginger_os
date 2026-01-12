#!/bin/bash
# LFS 12.4 - 8.75. MarkupSafe-3.0.2
source "/scripts/common.sh"
PKG_NAME="markupsafe"
ARCHIVE="MarkupSafe-3.0.2.tar.gz"
DIR_NAME="MarkupSafe-3.0.2"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
pip3 wheel -w dist --no-build-isolation --no-deps $PWD
pip3 install --no-index --no-user --find-links dist MarkupSafe
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
