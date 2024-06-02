#!/bin/bash
echo "################################################################################";
echo "#--------------------------Setting LFS variable--------------------------------#";
echo "################################################################################";
echo;echo;echo;
LFS=/mnt/lfs;
sleep 3;
# Extract package 
echo "################################################################################";
echo "#---------------------------------Cleaning-------------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 3;
# First, remove the currently installed documentation files to prevent 
# them from ending up in the final system, and to save about 35 MB:
rm -rf /usr/share/{info,man,doc}/*;
sleep 2;

# Second, on a modern Linux system, the libtool .la files are only useful 
# for libltdl. No libraries in LFS are loaded by libltdl, and it's known 
# that some .la files can cause BLFS package failures. Remove those files now:
find /usr/{lib,libexec} -name \*.la -delete;
sleep 2;

# The current system size is now about 3 GB, however the /tools directory is no 
# longer needed. It uses about 1 GB of disk space. Delete it now:
rm -rf /tools;
sleep 2;
echo "################################################################################";
echo "#-------------------------------Cleaning Complete------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;


echo "PLEASE NOTE";
echo;
echo "If you left the chroot environment to create a backup or restart building using a restore, \
remember to check that the virtual file systems are still mounted (findmnt | grep $LFS). If \
they are not mounted, remount them now as described in Section 7.3, “Preparing Virtual Kernel \
File Systems” and re-enter the chroot environment (see Section 7.4, “Entering the Chroot Environment”) \
before continuing.";

