#!/bin/bash
# LFS 12.4 - 8.74. Vim-9.1.1629
source "/scripts/common.sh"
PKG_NAME="vim"
ARCHIVE="vim-9.1.1629.tar.gz"
DIR_NAME="vim-9.1.1629"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
./configure --prefix=/usr
make $MAKEFLAGS
make install
ln -sv vim /usr/bin/vi
for L in  /usr/share/man/{rt,it,fr,pl,ru,ja,it.UTF-8,fr.UTF-8,pl.UTF-8,ru.UTF-8,ja.UTF-8,it.ISO8859-1,fr.ISO8859-1,pl.ISO8859-2,ru.KOI8-R,ja.EUC-JP}/man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done
cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc
set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "iterm") || (&term == "putty")
  set background=dark
endif
" End /etc/vimrc
EOF
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
