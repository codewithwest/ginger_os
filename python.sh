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
echo "#---------------------------Extracting Python package------------------------#";
echo "################################################################################";
echo;echo;echo;
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/Python" | grep ".tar");
echo "################################################################################";
echo "#--------------------Extracting binutils archive complete----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#----------------------------Change into Python dir--------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/Python");
pwd;
sleep 2;
echo "################################################################################";
echo "#------------------------------Configure tool----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
./configure --prefix=/usr        \
            --enable-shared      \
            --with-system-expat  \
            --enable-optimizations;
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
make test TESTOPTS="--timeout 120";
sleep 2;
echo "################################################################################";
echo "#--------------------------------Test suite complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# We use the pip3 command to install Python 3 programs and modules for all users as root 
# in several places in this book. This conflicts with the Python developers' recommendation: 
# to install packages into a virtual environment, or into the home directory of a regular 
# user (by running pip3 as this user). A multi-line warning is triggered whenever pip3 is 
# issued by the root user.

# The main reason for the recommendation is to avoid conflicts with the system's package 
# manager (dpkg, for example). LFS does not have a system-wide package manager, so this 
# is not a problem. Also, pip3 will check for a new version of itself whenever it's run. 
# Since domain name resolution is not yet configured in the LFS chroot environment, pip3 
# cannot check for a new version of itself, and will produce a warning.

# After we boot the LFS system and set up a network connection, a different warning will 
# be issued, telling the user to update pip3 from a pre-built wheel on PyPI (whenever a 
# new version is available). But LFS considers pip3 to be a part of Python 3, so it should 
# not be updated separately. Also, an update from a pre-built wheel would deviate from our 
# objective: to build a Linux system from source code. So the warning about a new version 
# of pip3 should be ignored as well. If you wish, you can suppress all these warnings by 
# running the following command, which creates a configuration file:
echo "################################################################################";
echo "#----------------------Create configuration file-------------------------------#";
echo "################################################################################";
echo;echo;echo;
cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF;
sleep 2;
echo "################################################################################";
echo "#-------------------Create configuration file complete-------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#------------------------------Install Documentation---------------------------#";
echo "################################################################################";
echo;echo;echo;
install -v -dm755 /usr/share/doc/python-3.12.5/html;
sleep 1;
tar --no-same-owner \
    -xvf ../python-3.12.5-docs-html.tar.bz2;
sleep1;
cp -R --no-preserve=mode python-3.12.5-docs-html/* \
    /usr/share/doc/python-3.12.5/html;
echo "################################################################################";
echo "#------------------------Install Documentation complete------------------------#";
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
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/Python");
echo "################################################################################";
echo "#--------------------------Clean Up Complete-----------------------------------#";
echo "################################################################################";
echo;echo;echo;