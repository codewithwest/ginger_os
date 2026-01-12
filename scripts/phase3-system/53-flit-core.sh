#!/bin/bash
# LFS 12.4 - 8.53. Flit-Core-3.12.0
source "/scripts/common.sh"
PKG_NAME="flit-core"
ARCHIVE="flit_core-3.12.0.tar.gz"
DIR_NAME="flit_core-3.12.0"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
pip3 wheel -w dist --no-build-isolation --no-deps $PWD
pip3 install --no-index --no-user --find-links dist flit_core
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
