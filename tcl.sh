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
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep tcl | grep tar);
echo "################################################################################";
echo "#----------------------------Extracting tcl package----------------------------#";
echo "################################################################################";
echo;echo;echo;
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/tcl" | grep "src.tar");
echo "################################################################################";
echo "#------------------------Extracting tcl archive complete-----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# change into the extracted package
echo "################################################################################";
echo "#-----------------------------Change into tcl dir------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/tcl");
pwd;
sleep 2;
echo "################################################################################";
echo "#------------------------------Configure tool----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
SRCDIR=$(pwd)
sleep 1;
cd unix
sleep 1;
pwd;
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --disable-rpath;
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
sed -e "s|$SRCDIR/unix|/usr/lib|" \
    -e "s|$SRCDIR|/usr/include|"  \
    -i tclConfig.sh
sleep 2;
sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.7|/usr/lib/tdbc1.1.7|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.7/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/tdbc1.1.7/library|/usr/lib/tcl8.6|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.7|/usr/include|"            \
    -i pkgs/tdbc1.1.7/tdbcConfig.sh
sleep 2;
sed -e "s|$SRCDIR/unix/pkgs/itcl4.2.4|/usr/lib/itcl4.2.4|" \
    -e "s|$SRCDIR/pkgs/itcl4.2.4/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/itcl4.2.4|/usr/include|"            \
    -i pkgs/itcl4.2.4/itclConfig.sh
sleep 2;
unset SRCDIR
echo "################################################################################";
echo "#---------------------------Make tool complete---------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#----------------------------------Make check----------------------------------#";
echo "################################################################################";
echo;echo;echo;
time make test;
echo "################################################################################";
echo "#--------------------------Make check complete---------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#---------------------------------Install tool---------------------------------#";
echo "################################################################################";
echo;echo;echo;
make install;
echo "################################################################################";
echo "#------------------------------Install tool complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# A few programs do not know about tcl yet and try to run its predecessor, lex. To support
#  those programs, create a symbolic link named lex that runs tcl in lex emulation mode, 
#  and also create the man page of lex as a symlink:
echo "################################################################################";
echo "#---Make the installed library writable so debugging symbols can be removed----#"; 
echo "################################################################################";
echo;echo;echo;
chmod -v u+w /usr/lib/libtcl8.6.so;
sleep 2;
echo "################################################################################";
echo "#------Install Tcl's headers. The next package, Expect, requires them----------#"; 
echo "################################################################################";
echo;echo;echo;
make install-private-headers;
sleep 2;
echo "################################################################################";
echo "#-------------------------Now make a necessary symbolic link-------------------#"; 
echo "################################################################################";
echo;echo;echo;
mln -sfv tclsh8.6 /usr/bin/tclsh;
sleep 2;
echo "################################################################################";
echo "#-----------Rename a man page that conflicts with a Perl man page--------------#"; 
echo "################################################################################";
echo;echo;echo;
mv /usr/share/man/man3/{Thread,Tcl_Thread}.3;
sleep 2;
echo "################################################################################";
echo "#-------------------------install the documentation----------------------------#"; 
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd ..;
sleep 2;
tar -xf $(find "$LFS/sources" -type f | grep "$LFS/sources/tcl" | grep "html.tar") --strip-components=1;
sleep 2;
mkdir -v -p /usr/share/doc/tcl-8.6.14;
sleep 2;
cp -v -r  ./html/* /usr/share/doc/tcl-8.6.14;
echo "################################################################################";
echo "#------------------------install the documentation complete--------------------#"; 
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/tcl");
echo "################################################################################";
echo "#--------------------------Clean Up Complete-----------------------------------#";
echo "################################################################################";
echo;echo;echo;