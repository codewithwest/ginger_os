#!/bin/bash
echo "################################################################################";
echo "#--------------------------Setting LFS variable--------------------------------#";
echo "################################################################################";
echo;echo;echo;
LFS=/mnt/lfs;
sleep 3;
echo "################################################################################";
echo "#-------------------------------------Restore----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 3;
# In case some mistakes have been made and you need to start over, you can use this backup
# to restore the system and save some recovery time. Since the sources are located under $LFS, 
# they are included in the backup archive as well, so they do not need to be downloaded 
# again. After checking that $LFS is set properly, you can restore the backup by executing 
# the following commands:

cd $LFS;
sleep 2;
rm -rf ./*;
sleep 2;
tar -xpf $HOME/lfs-temp-tools-12.1-systemd.tar.xz;
sleep 2;

echo "################################################################################";
echo "#---------------------------------Restore Complete-----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 3;


