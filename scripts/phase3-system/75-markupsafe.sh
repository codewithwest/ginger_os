#!/bin/bash
# LFS 12.4 - 8.75. MarkupSafe-3.0.2
source "/scripts/lib/common.sh"
PKG_NAME="markupsafe"
check_built "$PKG_NAME" && exit 0
extract "MarkupSafe"

pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

pip3 install --no-index --find-links dist Markupsafe

cleanup
mark_built "$PKG_NAME"
