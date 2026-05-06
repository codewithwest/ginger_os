#!/bin/bash
# LFS 12.4 - 8.52a. Packaging-3.11.0
source "/scripts/lib/common.sh"
PKG_NAME="packaging"
check_built "$PKG_NAME" && exit 0
extract "packaging"

pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist packaging

cleanup
mark_built "$PKG_NAME"