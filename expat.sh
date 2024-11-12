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
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | expat expat | expat tar);
echo "################################################################################";
echo "#---------------------------Extracting expat package----------------------------#";
echo "################################################################################";
echo;echo;echo;
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/expat" | grep ".tar");
echo "################################################################################";
echo "#--------------------Extracting binutils archive complete----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#----------------------------Change into expat dir------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/expat");
pwd;
sleep 2;
echo "################################################################################";
echo "#------------------------------Configure tool----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.6.2;
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
make check;
sleep 2;
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
echo "################################################################################";
echo "#------------------------------Install tool complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#------------------------------Install Documentation---------------------------#";
echo "################################################################################";
echo;echo;echo;
install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.6.2;
sleep 2;
echo "################################################################################";
echo "#----------------------------------Clean Up -----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/expat");
echo "################################################################################";
echo "#--------------------------Clean Up Complete-----------------------------------#";
echo "################################################################################";
echo;echo;echo;