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
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep shadow | grep tar);
echo "################################################################################";
echo "#----------------------------Extracting shadow package-----------------------#";
echo "################################################################################";
echo;echo;echo;
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/shadow" | grep ".tar");
echo "################################################################################";
echo "#---------------------Extracting shadow archive complete---------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# change into the extracted package
echo "################################################################################";
echo "#--------------------------Change into shadow dir----------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/shadow");
pwd;
sleep 2;
# Reinstalling shadow will cause the old libraries to be moved to <libraryname>.old. 
# While this is normally not a problem, in some cases it can trigger a linking bug in 
# ldconfig. This can be avoided by issuing the following two seds:
echo "################################################################################";
echo "#-------Disable the installation of the groups program and its man pages-------#";
echo "################################################################################";
echo;echo;echo;
sed -i 's/groups$(EXEEXT) //' src/Makefile.in;
sleep 2;
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
sleep 2;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
sleep 2;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
sleep 2;
echo "################################################################################";
echo "#------------------------------Disabling complete------------------------------#";
echo "################################################################################";
echo;echo;echo;
# sleep 2;
# Instead of using the default crypt method, use the much more secure YESCRYPT method of 
# password encryption, which also allows passwords longer than 8 characters. It is also 
# necessary to change the obsolete /var/spool/mail location for user mailboxes that Shadow 
# uses by default to the /var/mail location used currently. And, remove /bin and /sbin from 
# the PATH, since they are simply symlinks to their counterparts in /usr.
echo "################################################################################";
echo "#---------------use the much more secure YESCRYPT for password ecrytion--------#";
echo "################################################################################";
echo;echo;echo;
sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \
    -e 's:/var/spool/mail:/var/mail:'                   \
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                  \
    -i etc/login.defs;
sleep 2;
echo "################################################################################";
echo "#---------------------Prepare shadow for compilation---------------------------#";
echo "################################################################################";
echo;echo;echo;
touch /usr/bin/passwd;
sleep 2;
./configure --sysconfdir=/etc   \
            --disable-static    \
            --with-{b,yes}crypt \
            --without-libbsd    \
            --with-group-name-max-length=32;
sleep 2;
echo "################################################################################";
echo "#---------------------Prepare shadow for compilation complete----------------#";
echo "################################################################################";
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
make exec_prefix=/usr install;
sleep 1;
make -C man install-man;
echo "################################################################################";
echo "#------------------------------Install tool complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#---------------------------Configuring shadow---------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 1;
# This package contains utilities to add, modify, and delete users and groups; set and 
# change their passwords; and perform other administrative tasks. For a full explanation 
# of what password shadowing means, see the doc/HOWTO file within the unpacked source tree. 
# If you use Shadow support, keep in mind that programs which need to verify passwords 
# (display managers, FTP programs, pop3 daemons, etc.) must be Shadow-compliant. That is, 
# they must be able to work with shadowed passwords.
echo "################################################################################";
echo "#-----------------------enable shadowed passwords------------------------------#";
echo "################################################################################";
echo;echo;echo;
pwconv;
echo "################################################################################";
echo "#-------------------enable shadowed passwords complete-------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#---------------------enable shadowed group passwords--------------------------#";
echo "################################################################################";
echo;echo;echo;
grpconv;
echo "################################################################################";
echo "#----------------enable shadowed group passwords complete----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# Second, to change the default parameters, the file /etc/default/useradd must be created 
# and tailored to suit your particular needs. Create it with:
echo "################################################################################";
echo "#-----------------------create /etc/default/useradd----------------------------#";
echo "################################################################################";
echo;echo;echo;
mkdir -p /etc/default;
sleep 1;
useradd -D --gid 999;
echo "################################################################################";
echo "#------------------create /etc/default/useradd complete------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#------------------------------set root password-------------------------------#";
echo "################################################################################";
echo;echo;echo;
passwd root
echo "################################################################################";
echo "#-------------------------set root password complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#-----------------------Configuring shadow complete----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 1;
echo "################################################################################";
echo "#----------------------------------Clean Up -----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/shadow");
echo "################################################################################";
echo "#--------------------------Clean Up Complete-----------------------------------#";
echo "################################################################################";
echo;echo;echo;