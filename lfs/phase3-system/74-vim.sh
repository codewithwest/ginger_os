#!/bin/bash
# LFS 13.0  - 8.74. Vim-9.1.1629
source "/lfs/lib/common.sh"
PKG_NAME="vim"
check_built "$PKG_NAME" && exit 0
extract "vim"

echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h

./configure --prefix=/usr

make $MAKEFLAGS
rm -fv /usr/bin/{ex,view,rview,rvim,vimdiff}
make -j1 install

ln -sfv vim /usr/bin/vi
for L in  /usr/share/man/{,*/}man1/vim.1; do
    ln -sfv vim.1 $(dirname $L)/vi.1
done

ln -sfv ../vim/vim91/doc /usr/share/doc/vim-9.1.1629

cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF


cleanup
mark_built "$PKG_NAME"
