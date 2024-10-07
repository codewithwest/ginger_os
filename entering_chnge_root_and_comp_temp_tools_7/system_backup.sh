#!/bin/bash
echo "################################################################################";
echo "#--------------------------Setting LFS variable--------------------------------#";
echo "################################################################################";
echo;echo;echo;
LFS=/mnt/lfs;
sleep 3;
echo "################################################################################";
echo "#-------------------------------------Backup-----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 3;
# At this point the essential programs and libraries have been created and 
# your current LFS system is in a good state. Your system can now be backed 
# up for later reuse. In case of fatal failures in the subsequent chapters, 
# it often turns out that removing everything and starting over (more carefully) 
# is the best way to recover. Unfortunately, all the temporary files will be 
# removed, too. To avoid spending extra time to redo something which has been 
# done successfully, creating a backup of the current LFS system may prove useful.

echo If you have decided to make a backup, leave the chroot environment;

exit;

# Before making a backup, unmount the virtual file systems:

mountpoint -q $LFS/dev/shm && umount $LFS/dev/shm
umount $LFS/dev/pts
umount $LFS/{sys,proc,run,dev}

# Make sure you have at least 1 GB free disk space (the source tarballs will be 
# included in the backup archive) on the file system containing the directory where 
# you create the backup archive.

# Note that the instructions below specify the home directory of the host 
# system's root user, which is typically found on the root file system. 
# Replace $HOME by a directory of your choice if you do not want to have 
# the backup stored in root's home directory.

# Create the backup archive by running the following command:
cd $LFS
tar -cJpf $HOME/lfs-temp-tools-12.2-systemd.tar.xz .

echo "################################################################################";
echo "#---------------------------------Backup Complete------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 3;