#!/bin/bash
# LFS 13.0  - 8.36. Bash-5.3
source "/lfs/lib/common.sh"
PKG_NAME="bash"
check_built "$PKG_NAME" && exit 0
extract "bash"

./configure --prefix=/usr             \
            --without-bash-malloc     \
            --with-installed-readline \
            --docdir=/usr/share/doc/bash-5.3

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
# Note: Executing building bash usually requires re-execing bash, 
# but for a scripted build, we'll continue.
