#!/bin/bash
# LFS 12.4 - 6.7. File-5.46
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="file-temp"
ARCHIVE="file-5.46.tar.gz"
DIR_NAME="file-5.46"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
mkdir build
pushd build
  ../configure --disable-bzlib      \
               --disable-libseccomp \
               --disable-xzlib      \
               --disable-zlib
  make
popd
./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
make $MAKEFLAGS FILE_COMPILE=$(pwd)/build/src/file
make DESTDIR=$LFS install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
