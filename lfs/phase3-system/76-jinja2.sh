#!/bin/bash
# LFS 13.0  - 8.76. Jinja2-3.1.6
source "/lfs/lib/common.sh"
PKG_NAME="jinja2"
check_built "$PKG_NAME" && exit 0
extract "jinja2"

pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

pip3 install --no-index --find-links dist Jinja2

cleanup
mark_built "$PKG_NAME"
