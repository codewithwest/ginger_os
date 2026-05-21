#!/bin/bash
# LFS 13.0  - 8.73. Texinfo-7.2
source "/lfs/lib/common.sh"
PKG_NAME="texinfo"
check_built "$PKG_NAME" && exit 0
extract "texinfo"

sed 's/! $output_file eq/$output_file ne/' -i tp/Texinfo/Convert/*.pm


./configure --prefix=/usr


make $MAKEFLAGS
make install

make TEXMF=/usr/share/texmf install-tex

pushd /usr/share/info
  rm -v dir
  for f in *
    do install-info $f dir 2>/dev/null
  done
popd

cleanup
mark_built "$PKG_NAME"
# Optional: install-tex
