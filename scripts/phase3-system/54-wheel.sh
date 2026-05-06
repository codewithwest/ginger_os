#!/bin/bash
# LFS 12.4 - 8.54. Wheel-0.45.1
source "/scripts/lib/common.sh"
PKG_NAME="wheel"
check_built "$PKG_NAME" && exit 0
extract "wheel"

pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist wheel

cleanup
mark_built "$PKG_NAME"
