echo "################################################################################";
echo "#--------------------------Setting LFS variable--------------------------------#";
echo "################################################################################";
echo;echo;echo;
LFS=/mnt/lfs;
echo "################################################################################";
echo "#----------------------Run this as Base OS root!!!!!!!!!!----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#-----------------------7.2. Changing Ownership--------------------------------#";
echo "################################################################################";
echo;echo;echo;
chown --from lfs -R root:root $LFS/{usr,lib,var,etc,bin,sbin,tools}
case $(uname -m) in
  x86_64) chown --from lfs -R root:root $LFS/lib64 ;;
esac;
sleep 5;
echo "################################################################################";
echo "#--------------------7.2. Changing Ownership Complete--------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#---------------7.3. Preparing Virtual Kernel File Systems---------------------#";
echo "################################################################################";
echo;echo;echo;
mkdir -pv $LFS/{dev,proc,sys,run};
sleep 5;
echo "################################################################################";
echo "#-------------------7.3.1. Mounting and Populating /dev------------------------#";
echo "################################################################################";
echo;echo;echo;
mount -v --bind /dev $LFS/dev;
sleep 5;
echo "################################################################################";
echo "#-----------------7.3.1. Mounting and Populating /dev complete-----------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#------------------7.3.2. Mounting Virtual Kernel File Systems-----------------#";
echo "################################################################################";
echo;echo;echo;
mount -vt devpts devpts -o gid=5,mode=0620 $LFS/dev/pts;
sleep 1;
mount -vt proc proc $LFS/proc;
sleep 1;
mount -vt sysfs sysfs $LFS/sys;
sleep 1;
mount -vt tmpfs tmpfs $LFS/run;
# In other host systems /dev/shm is a mount point for a tmpfs. 
# In that case the mount of /dev above will only create 
# /dev/shm as a directory in the chroot environment. 
# In this situation we must explicitly mount a tmpfs:
if [ -h $LFS/dev/shm ]; then
  install -v -d -m 1777 $LFS$(realpath /dev/shm)
else
  mount -vt tmpfs -o nosuid,nodev tmpfs $LFS/dev/shm
fi
sleep 5;
echo "################################################################################";
echo "#---------------7.3.2. Mounting Virtual Kernel File Systems complete-----------#";
echo "################################################################################";
echo;echo;echo;

echo "################################################################################";
echo "#------------7.3. Preparing Virtual Kernel File Systems Complete---------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#-----------------7.4. Entering the Chroot Environment-------------------------#";
echo "################################################################################";
echo;echo;echo;
chroot "$LFS" /usr/bin/env -i   \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin     \
    MAKEFLAGS="-j$(nproc)"      \
    TESTSUITEFLAGS="-j$(nproc)" \
    /bin/bash --login;
sleep 5;
echo "################################################################################";
echo "#-----------------7.4. Entering the Chroot Environment complete----------------#";
echo "################################################################################";
echo;echo;echo;

# "You should be in lfs user root..."

