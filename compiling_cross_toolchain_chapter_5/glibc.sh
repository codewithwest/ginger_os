#!/bin/bash
echo "################################################################################";
echo "#--------------------------Setting LFS variable--------------------------------#";
echo "################################################################################";
echo;echo;echo;
LFS=/mnt/lfs;
echo $LFS;
sleep 5;
echo "################################################################################";
echo "#-------------------------Change into sources dir------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $LFS/sources;
sleep 5;
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep glibc |  tar )
echo "################################################################################";
echo "#-------------------------Extracting glibc package-----------------------------#";
echo "################################################################################";
echo;echo;echo;
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/glibc" | grep ".tar")
sleep 5;
echo "################################################################################";
echo "#--------------------Extracting binutils archive complete----------------------#";
echo "################################################################################";
echo;echo;echo;

echo "################################################################################";
echo "#--------------------------Change into glibc dir-------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/glibc");
sleep 2;
#First, create a symbolic link for LSB compliance. Additionally, for x86_64, 
# create a compatibility symbolic link required for proper operation of the 
# dynamic library loader:
echo "################################################################################";
echo "#-------------------create a symbolic link for LSB compliance------------------#";
echo "################################################################################";
echo;echo;echo;
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    ;;
esac;
sleep 5;
echo "################################################################################";
echo "#-------------create a symbolic link for LSB compliance complete---------------#";
echo "################################################################################";
echo;echo;echo;
# Some of the Glibc programs use the non-FHS-compliant /var/db directory to store 
# their runtime data. Apply the following patch to make such programs store their 
# runtime data in the FHS-compliant locations:
# create a build dir
echo "################################################################################";
echo "#---------------------------------Apply patch----------------------------------#";
echo "################################################################################";
echo;echo;echo;
patch -Np1 -i ../glibc-2.40-fhs-1.patch;
sleep 5;
# create a build dir
echo "################################################################################";
echo "#---------------------------Applying patch complete----------------------------#";
echo "################################################################################";
echo;echo;echo;
# create a build dir
# create a build dir
echo "################################################################################";
echo "#----------------------------Create build dir----------------------------------#";
echo "################################################################################";
echo;echo;echo;
mkdir -v build;
sleep 2;
echo "################################################################################";
echo "#--------------------------Change into build dir-------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd build;
sleep 2;
# 
echo "################################################################################";
echo "#---Ensure that the ldconfig and sln utilities are installed into /usr/sbin----#";
echo "################################################################################";
echo;echo;echo;
echo "rootsbindir=/usr/sbin" > configparms;

echo "################################################################################";
echo "#------------------------------Configure tool----------------------------------#";
echo "################################################################################";
echo;echo;echo;
# Prepare package for compilation:
../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=4.19               \
      --with-headers=$LFS/usr/include    \
      --disable-nscd                     \
      libc_cv_slibdir=/usr/lib;
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
echo "#---------------------------------Install tool---------------------------------#";
echo "################################################################################";
echo;echo;echo;
make DESTDIR=$LFS install;
echo "################################################################################";
echo "#------------------------------Install tool complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# 
echo "################################################################################";
echo "#-------Fix a hard coded path to the executable loader in the ldd script-------#";
echo "################################################################################";
echo;echo;echo;
sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd;
echo "################################################################################";
echo "#------------------------------- clean up script-------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/glibc");
echo "################################################################################";
echo "#---------------------------clean up script complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;