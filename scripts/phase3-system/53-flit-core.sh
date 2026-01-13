#!/bin/bash
# LFS 12.4 - 8.53. Flit-core-3.11.0
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"
PKG_NAME="flit-core"
check_built "$PKG_NAME" && exit 0
extract "flit_core"
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist flit_core
cd .. && rm -rf "flit_core-"*
mark_built "$PKG_NAME"
# Note: Use of pip3 in chroot requires python to be installed first.
