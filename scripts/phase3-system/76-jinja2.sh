#!/bin/bash
# LFS 12.4 - 8.76. Jinja2-3.1.6
source "/scripts/common.sh"
PKG_NAME="jinja2"
ARCHIVE="jinja2-3.1.6.tar.gz"
DIR_NAME="jinja2-3.1.6"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
pip3 wheel -w dist --no-build-isolation --no-deps $PWD
pip3 install --no-index --no-user --find-links dist Jinja2
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
