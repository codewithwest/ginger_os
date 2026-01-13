#!/bin/bash
# LFS 12.4 - 6.7. File-5.46
source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="file-temp"
check_built "$PKG_NAME" && exit 0

extract "file"

log "PROCESS" "Compiling File (Temporary Tools)..."

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

rm -v $LFS/usr/lib/libmagic.la

cd ..
rm -rf "file-"*

mark_built "$PKG_NAME"
