#!/bin/bash
# LFS 12.4 - 8.36. Bash-5.3
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"
PKG_NAME="bash"
check_built "$PKG_NAME" && exit 0
extract "bash"

./configure --prefix=/usr             \
            --without-bash-malloc     \
            --with-installed-readline \
            --docdir=/usr/share/doc/bash-5.3

make $MAKEFLAGS
make install

cd .. && rm -rf "bash-"*
mark_built "$PKG_NAME"
# Note: Executing building bash usually requires re-execing bash, 
# but for a scripted build, we'll continue.
