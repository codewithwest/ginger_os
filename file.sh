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
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep binutils | grep tar);
echo "################################################################################";
echo "#----------------------------Extracting file package-----------------------------#";
echo "################################################################################";
echo;echo;echo;
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep file | grep tar);
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/file" | grep ".tar");
echo "################################################################################";
echo "#--------------------Extracting file archive complete----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# change into the extracted package
echo "################################################################################";
echo "#-----------------------------Change into file dir-------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/file");
pwd;
sleep 2;
echo "################################################################################";
echo "#---------------------------Compile the package--------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
time make prefix=/usr;
echo "################################################################################";
echo "#--------------------Compile the package completed-----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#----------------------------------Make check----------------------------------#";
echo "################################################################################";
echo;echo;echo;
time make check;
echo "################################################################################";
echo "#--------------------------Make check complete---------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#---------------------------------Install tool---------------------------------#";
echo "################################################################################";
echo;echo;echo;
make prefix=/usr install;
echo "################################################################################";
echo "#------------------------------Install tool complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 1;
echo "################################################################################";
echo "#------------------------Remove the static library-----------------------------#";
echo "################################################################################";
echo;echo;echo;
rm -v /usr/lib/libfile.a;
sleep 2;
echo "################################################################################";
echo "#----------------------------------Clean Up -----------------------------------#";
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
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/file");
echo "################################################################################";
echo "#--------------------------Clean Up Complete-----------------------------------#";
echo "################################################################################";
echo;echo;echo;