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
echo "################################################################################";
echo "#----------------------------Extracting expect package-----------------------#";
echo "################################################################################";
echo;echo;echo;
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/expect" | grep ".tar");
echo "################################################################################";
echo "#---------------------Extracting expect archive complete---------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# change into the extracted package
echo "################################################################################";
echo "#--------------------------Change into expect dir----------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/expect");
pwd;
sleep 2;
echo "################################################################################";
echo "#------------Verify that the PTYs are working properly-------------------------#";
echo "################################################################################";
echo;echo;echo;
python3 -c 'from pty import spawn; spawn(["echo", "ok"])';
sleep 2;
echo "################################################################################";
echo "#---------Verify that the PTYs are working properly complete-------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#----------------------------Apply expect patch------------------------------#";
echo "################################################################################";
echo;echo;echo;
patch -Np1 -i $(find "$LFS/sources" -type f | grep "$LFS/sources/expect" | grep "patch");
sleep 2;
echo "################################################################################";
echo "#------------------------Apply expect patch complete-------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#------------------------------Configure tool----------------------------------#";
echo "################################################################################";
echo;echo;echo;
./configure --prefix=/usr           \
            --with-tcl=/usr/lib     \
            --enable-shared         \
            --disable-rpath         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include;
sleep 2;
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
echo "#----------------------------------Make test-----------------------------------#";
echo "################################################################################";
echo;echo;echo;
time make test;
echo "################################################################################";
echo "#--------------------------Make test complete----------------------------------#";
echo "################################################################################";
echo;echo;echo;
echo "################################################################################";
echo "#---------------------------------Install tool---------------------------------#";
echo "################################################################################";
echo;echo;echo;
make install;
sleep 2;
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib;
echo "################################################################################";
echo "#------------------------------Install tool complete---------------------------#";
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
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/expect");
echo "################################################################################";
echo "#--------------------------Clean Up Complete-----------------------------------#";
echo "################################################################################";
echo;echo;echo;