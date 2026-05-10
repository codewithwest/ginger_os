#!/bin/bash
# LFS 12.4 - 8.55. Setuptools-75.8.0
source "/lfs/lib/common.sh"
PKG_NAME="setuptools"
check_built "$PKG_NAME" && exit 0
extract "setuptools"

pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist setuptools

cleanup
mark_built "$PKG_NAME"
