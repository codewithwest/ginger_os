#!/bin/bash
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

PKG_NAME="diffutils-temp"
check_built "$PKG_NAME" && exit 0

extract "diffutils"

# When cross-compiling newer versions of Diffutils (like 3.12), some runtime tests 
# for strcasecmp will fail because they can't be run. We explicitly 
# tell configure that it works (which is true for glibc).
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            gl_cv_func_strcasecmp_works=y \
            --build=$(./build-aux/config.guess)

make $MAKEFLAGS
make DESTDIR=$LFS install

cd ..
cleanup

mark_built "$PKG_NAME"
