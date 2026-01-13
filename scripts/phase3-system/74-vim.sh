#!/bin/bash
# LFS 12.4 - 8.74. Vim-9.1.1629
source "$(dirname "$(readlink -f "$0")")/common.sh"
PKG_NAME="vim"
check_built "$PKG_NAME" && exit 0
extract "vim"
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
./configure --prefix=/usr
make $MAKEFLAGS
make install
ln -sv vim /usr/bin/vi
for L in  /usr/share/man/{main,it,pl}/man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done

cat > /etc/vimrc << "EOF"
set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif
EOF

cd .. && rm -rf "vim"*
mark_built "$PKG_NAME"
