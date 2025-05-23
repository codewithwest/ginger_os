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
echo "#---------------------------Extracting systemd package------------------------#";
echo "################################################################################";
echo;echo;echo;
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/systemd" | grep ".tar");
echo "################################################################################";
echo "#--------------------Extracting binutils archive complete----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# Remove two unneeded groups, render and sgx, from the default udev rules:
echo "################################################################################";
echo "#---------------------------Remove unneeded groups-----------------------------#";
echo "################################################################################";
echo;echo;echo;
sed -i -e 's/GROUP="render"/GROUP="video"/' \
       -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in;
echo "################################################################################";
echo "#---------------------------Remove unneeded groups complete--------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# Prepare systemd for compilation:
echo "################################################################################";
echo "#---------------------------Prepare systemd for compilation--------------------#";
echo "################################################################################";
echo;echo;echo;
mkdir -p build;
sleep 1;
cd       build;
sleep 1;
meson setup ..                \
      --prefix=/usr           \
      --buildtype=release     \
      -D default-dnssec=no    \
      -D firstboot=false      \
      -D install-tests=false  \
      -D ldconfig=false       \
      -D sysusers=false       \
      -D rpmmacrosdir=no      \
      -D homed=disabled       \
      -D userdb=false         \
      -D man=disabled         \
      -D mode=release         \
      -D pamconfdir=no        \
      -D dev-kvm-mode=0660    \
      -D nobody-group=nogroup \
      -D sysupdate=disabled   \
      -D ukify=disabled       \
      -D docdir=/usr/share/doc/systemd-256.4;
echo "################################################################################";
echo "#---------------------------Prepare systemd complete---------------------------#";
echo "################################################################################";
# Compile the package:
echo "################################################################################";
echo "#------------------------------------Make tool---------------------------------#";
echo "################################################################################";
echo;echo;echo;
time ninja;
sleep 2;
echo "################################################################################";
echo "#---------------------------Make tool complete---------------------------------#";
echo "################################################################################";
# Some tests need a basic /etc/os-release file. To test the results, issue:
echo "################################################################################";
echo "#---------------------------------Test suite-----------------------------------#";
echo "################################################################################";
echo;echo;echo;
echo 'NAME="Linux From Scratch"' > /etc/os-release;
sleep 1;
ninja test;
echo "################################################################################";
echo "#--------------------------------Test suite complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# Install the package:
echo "################################################################################";
echo "#------------------------------Install tool------------------------------------#";
echo "################################################################################";
echo;echo;echo;
ninja install;
sleep 1;
tar -xf ../../systemd-man-pages-256.4.tar.xz \
    --no-same-owner --strip-components=1   \
    -C /usr/share/man;
exho "################################################################################";
echo "#------------------------------Install tool complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# Create the /etc/machine-id file needed by systemd-journald:
echo "################################################################################";
echo "#--------------------------Create the /etc/machine-id file---------------------#";
echo "################################################################################";
echo;echo;echo;
systemd-machine-id-setup;
# Set up the basic target structure:
echo "################################################################################";
echo "#--------------------------Set up the basic target structure-------------------#";
echo "################################################################################";
echo;echo;echo;
systemctl preset-all;
echo "################################################################################";
echo "#--------------------------Set up the basic target structure complete----------#";
echo "################################################################################";
sleep 2;
echo "################################################################################";
echo "#----------------------------------Clean Up -----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/systemd");
echo "################################################################################";
echo "#--------------------------Clean Up Complete-----------------------------------#";
echo "################################################################################";
echo;echo;echo;