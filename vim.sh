#!/bin/bash
echo "################################################################################";
echo "#--------------------------Setting LFS variable--------------------------------#";
echo "################################################################################";
echo;echo;echo;
# LFS=/mnt/lfs;
sleep 5;
# Extract package 
echo "################################################################################";
echo "#-------------------------Change into sources dir------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $LFS/sources;
pwd;
sleep 5;
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep grep | grep tar);
echo "################################################################################";
echo "#---------------------------Extracting vim package------------------------#";
echo "################################################################################";
echo;echo;echo;
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/vim" | grep ".tar");
echo "################################################################################";
echo "#--------------------Extracting binutils archive complete----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#----------------------------Change into vim dir--------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/vim");
pwd;
sleep 2;
# First, change the default location of the vimrc configuration file to /etc:
echo "################################################################################";
echo "#--------------------------Change the default location of the vimrc file-------#";
echo "################################################################################";
echo;echo;echo;
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h;
sleep 2;
echo "################################################################################";
echo "#------------------------------Configure tool----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
./configure --prefix=/usr;
echo "################################################################################";
echo "#-------------------------Configure tool completed-----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#------------------------------------Make tool---------------------------------#";
echo "################################################################################";
echo;echo;echo;
time make;
echo "################################################################################";
echo "#---------------------------Make tool complete---------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#---------------------------------Test suite-----------------------------------#";
echo "################################################################################";
echo;echo;echo;
chown -R tester .;
sleep 2;
su tester -c "TERM=xterm-256color LANG=en_US.UTF-8 make -j1 test" \
   &> vim-test.log;
echo "################################################################################";
echo "#--------------------------------Test suite complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#------------------------------Install tool------------------------------------#";
echo "################################################################################";
echo;echo;echo;
make install;
sleep 2;
echo "################################################################################";
echo "#------------------------------Install tool complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# Many users reflexively type vi instead of vim. To allow execution of vim when users 
# habitually enter vi, create a symlink for both the binary and the man page in the provided 
# languages:
echo "################################################################################";
echo "#--------------------------Create a symlink for both the binary----------------#";
echo "################################################################################";
echo;echo;echo;
ln -sv vim /usr/bin/vi;
sleep 2;
for L in  /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done;
sleep 2;
# By default, Vim's documentation is installed in /usr/share/vim. The following symlink 
# allows the documentation to be accessed via /usr/share/doc/vim-9.1.0660, making it 
# consistent with the location of documentation for other packages:
echo "################################################################################";
echo "#--------------------------Create a symlink for documentation-------------------#";
echo "################################################################################";
echo;echo;echo;
ln -sv ../vim/vim91/doc /usr/share/doc/vim-9.1.0660;
sleep 2;
# By default, vim runs in vi-incompatible mode. This may be new to users who have used other 
# editors in the past. The “nocompatible” setting is included below to highlight the fact 
# that a new behavior is being used. It also reminds those who would change to “compatible” 
# mode that it should be the first setting in the configuration file. This is necessary 
# because it changes other settings, and overrides must come after this setting. Create a 
# default vim configuration file by running the following:
echo "################################################################################";
echo "#--------------------------Create a default vim configuration file-------------#";
echo "################################################################################";
echo;echo;echo;
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
EOF;
sleep 2;
echo "################################################################################";
echo "#----------------Create a default vim configuration file complete--------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#----------------------------------Clean Up -----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/vim");
echo "################################################################################";
echo "#--------------------------Clean Up Complete-----------------------------------#";
echo "################################################################################";
echo;echo;echo;