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
echo "#---------------------------Extracting procps-ng package------------------------#";
echo "################################################################################";
echo;echo;echo;
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/procps-ng" | grep ".tar");
echo "################################################################################";
echo "#--------------------Extracting binutils archive complete----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#----------------------------Change into procps-ng dir--------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/procps-ng");
pwd;
sleep 2;
echo "################################################################################";
echo "#------------------------------Configure tool----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
./configure --prefix=/usr                           \
            --docdir=/usr/share/doc/procps-ng-4.0.4 \
            --disable-static                        \
            --disable-kill                          \
            --with-systemd;
echo "################################################################################";
echo "#-------------------------Configure tool completed-----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#------------------------------------Make tool---------------------------------#";
echo "################################################################################";
echo;echo;echo;
time make src_w_LDADD='$(LDADD) -lsystemd';
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
sleep 1;
su tester -c "PATH=$PATH make check";
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
echo "#----------------------------------Clean Up -----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/procps-ng");
echo "################################################################################";
echo "#--------------------------Clean Up Complete-----------------------------------#";
echo "################################################################################";
echo;echo;echo;