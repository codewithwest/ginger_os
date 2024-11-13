#!/bin/bash
echo "################################################################################";
echo "#--------------------------Setting LFS variable--------------------------------#";
echo "################################################################################";
echo;echo;echo;
LFS=/mnt/lfs;
sleep 5;
# Extract package 
echo "################################################################################";
echo "#-------------------------Change into sources dir------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $LFS/sources;
pwd;
sleep 5;
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep mpfr | grep tar);
echo "################################################################################";
echo "#-------------------------Extracting mpfr package--------------------------#";
echo "################################################################################";
echo;echo;echo;
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/mpfr" | grep ".tar");

echo "################################################################################";
echo "#--------------------Extracting mpfr archive complete----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# change into the extracted package
echo "################################################################################";
echo "#--------------------------Change into mpfr dir----------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/mpfr");
pwd
sleep 2;
# Prepare package for compilation:
echo "################################################################################";
echo "#------------------------------Configure tool----------------------------------#";
echo "################################################################################";
echo;echo;echo;
./configure --prefix=/usr        \
            --disable-static     \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.2.1;
sleep 2;
# make package
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
sleep 2;
make html;
echo "################################################################################";
echo "#---------------------------Make tool complete---------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#----------------------------------Make check----------------------------------#";
echo "################################################################################";
echo;echo;echo;
make check;
echo "################################################################################";
echo "#--------------------------Make check complete---------------------------------#";
echo "################################################################################";
# install package
echo "################################################################################";
echo "#---------------------------------Install tool---------------------------------#";
echo "################################################################################";
echo;echo;echo;
make install;
sleep 1;
make install-html;
echo "################################################################################";
echo "#------------------------------Install tool complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# clean up
echo "################################################################################";
echo "#----------------------------------Clean Up -----------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/mpfr")
echo "################################################################################";
echo "#--------------------------Clean Up Complete-----------------------------------#";
echo "################################################################################";
echo;echo;echo;