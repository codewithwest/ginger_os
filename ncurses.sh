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
echo "#-------------------------Extracting ncurses package---------------------------#";
echo "################################################################################";
echo;echo;echo;
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/ncurses" | grep ".tar");

echo "################################################################################";
echo "#--------------------Extracting ncurses archive complete-----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# change into the extracted package
echo "################################################################################";
echo "#--------------------------Change into ncurses dir-----------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/ncurses");
pwd;
sleep 2;
echo "################################################################################";
echo "#------------------------------Configure tool----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-normal        \
            --with-cxx-shared       \
            --enable-pc-files       \
            --with-pkg-config-libdir=/usr/lib/pkgconfig;
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
echo "This package has a test suite, but it can only be run after the package has been installed. 
The tests reside in the test/ directory. See the README file in that directory for further 
details.";
# The installation of this package will overwrite libncursesw.so.6.5 in-place. It may crash 
# the shell process which is using code and data from the library file. Install the package 
# with DESTDIR, and replace the library file correctly using install command (the header 
# curses.h is also edited to ensure the wide-character ABI to be used as what we've done in 
# Section 6.3, “Ncurses-6.5”):
sleep 2;
echo "################################################################################";
echo "#---------------------------------Install tool---------------------------------#";
echo "################################################################################";
echo;echo;echo;
make DESTDIR=$PWD/dest install;
install -vm755 dest/usr/lib/libncursesw.so.6.5 /usr/lib
rm -v  dest/usr/lib/libncursesw.so.6.5
sed -e 's/^#if.*XOPEN.*$/#if 1/' \
    -i dest/usr/include/curses.h
cp -av dest/* /;
sleep 2;
echo "################################################################################";
echo "#------------------------------Install tool complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "Many applications still expect the linker to be able to find non-wide-character 
Ncurses libraries. Trick such applications into linking with wide-character libraries
by means of symlinks (note that the .so links are only safe with curses.h edited to 
always use the wide-character ABI):";
echo "################################################################################";
echo "#--Trick such applications into linking with wide-character -------------------#";
echo "#------------------------libraries by means of symlinks------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
for lib in ncurses form panel menu ; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
done;
echo;echo;echo;
echo "################################################################################";
echo "#---------------------Trick complete-------------------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#-------------Finally, make sure that old applications that look for-----------#";
echo "#------------------lcurses at build time are still buildable-------------------#";
echo "################################################################################";
echo;echo;echo;
ln -sfv libncursesw.so /usr/lib/libcurses.so;
sleep 2;
echo "################################################################################";
echo "#-------------------------Install ncurses Documentation------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cp -v -R doc -T /usr/share/doc/ncurses-6.5;
echo "################################################################################";
echo "#----------------------------------Clean Up -----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/ncurses");
echo "################################################################################";
echo "#--------------------------Clean Up Complete-----------------------------------#";
echo "################################################################################";
echo;echo;echo;