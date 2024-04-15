# Creating sources folder
mkdir -v $LFS/sources;
sleep 2;
# Make this directory writable and sticky. 
# “Sticky” means that even if multiple users have write permission on a directory, 
# only the owner of a file can delete the file within a sticky directory. 
# The following command will enable the write and sticky modes:
chmod -v a+wt $LFS/sources;
sleep 2;
cd $LFS/sources;
sleep 2;
# Get packages list
wget https://www.linuxfromscratch.org/lfs/downloads/stable-systemd/wget-list;
sleep 2;
# Get packages m2sums list
wget https://www.linuxfromscratch.org/lfs/downloads/stable-systemd/md5sums;
sleep 2
# download the packages
wget --input-file=wget-list --continue --directory-prefix=$LFS/sources;
#verify the checksums
pushd $LFS/sources
  md5sum -c md5sums
popd;

# give file ownership to lfs
chown root:root $LFS/sources/*;