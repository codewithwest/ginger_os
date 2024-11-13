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
echo "#---------------------------Extracting kmod package------------------------#";
echo "################################################################################";
echo;echo;echo;
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/kmod" | grep ".tar");
echo "################################################################################";
echo "#--------------------Extracting binutils archive complete----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#----------------------------Change into kmod dir--------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/kmod");
pwd;
sleep 2;
echo "################################################################################";
echo "#------------------------------Configure tool----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --with-openssl    \
            --with-xz         \
            --with-zstd       \
            --with-zlib       \
            --disable-manpages;
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
# The test suite of this package requires raw kernel headers (not the “sanitized” kernel 
# headers installed earlier), which are beyond the scope of LFS.

# Install the package and recreate some symlinks for compatibility with Module-Init-Tools 
# (the package that previously handled Linux kernel modules). The building system will 
# create all these symlinks in /usr/bin, but we only want lsmod there and all other 
# symlinks in /usr/sbin instead:
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#------------------------------Install tool------------------------------------#";
echo "################################################################################";
echo;echo;echo;
make install;
sleep 2;
for target in depmod insmod modinfo modprobe rmmod; do
  ln -sfv ../bin/kmod /usr/sbin/$target
  rm -fv /usr/bin/$target
done;
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
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/kmod");
echo "################################################################################";
echo "#--------------------------Clean Up Complete-----------------------------------#";
echo "################################################################################";
echo;echo;echo;