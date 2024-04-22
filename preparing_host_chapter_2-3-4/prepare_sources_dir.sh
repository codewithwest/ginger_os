LFS=/mnt/lfs;
# Creating sources folder
echo "################################################################################";
echo "#----------------------------Creating sources Dir------------------------------#";
echo "################################################################################";
mkdir -v $LFS/sources;
echo "################################################################################";
echo "#------------------------sources Dir creation complete-------------------------#";
echo "################################################################################";
sleep 2;
# Make this directory writable and sticky. 
# “Sticky” means that even if multiple users have write permission on a directory, 
# only the owner of a file can delete the file within a sticky directory. 
# The following command will enable the write and sticky modes:
echo "################################################################################";
echo "#---------------Changing sorces dir permisions sources Dir---------------------#";
echo "################################################################################";
chmod -v a+wt $LFS/sources;
echo "################################################################################";
echo "#------------Changing sorces dir permisions sources Dir complete!--------------#";
echo "################################################################################";
sleep 2;
echo "################################################################################";
echo "#--------------------------Changing to sources dir-----------------------------#";
echo "################################################################################";
cd $LFS/sources;
echo "################################################################################";
echo "#-----------------------------In sources dir-----------------------------------#";
echo "################################################################################";
sleep 2;
# Get packages list
echo "################################################################################";
echo "#-------------------------Get package list-------------------------------------#";
echo "################################################################################";
wget https://www.linuxfromscratch.org/lfs/downloads/stable-systemd/wget-list || echo "Network Error";
echo "################################################################################";
echo "#----------------------Get package list complete-------------------------------#";
echo "################################################################################";
sleep 2;
# Get packages m2sums list'
echo "################################################################################";
echo "#-------------------------Get md5sum list-------------------------------------#";
echo "################################################################################";
wget https://www.linuxfromscratch.org/lfs/downloads/stable-systemd/md5sums  || echo "Network Error";
echo "################################################################################";
echo "#----------------------Get md5sum list complete-------------------------------#";
echo "################################################################################";
sleep 2
# download the packages
echo "################################################################################";
echo "#-------------------------Get packacges list-----------------------------------#";
echo "################################################################################";
wget --input-file=wget-list --continue --directory-prefix=$LFS/sources || echo "Network Error";
echo "################################################################################";
echo "#----------------------Get packacges list complete-----------------------------#";
echo "################################################################################";
sleep 5;
#verify the checksums
echo "################################################################################";
echo "#--------------------------Packages Checksum check-----------------------------#";
echo "################################################################################";
sleep 5;
pushd $LFS/sources
  md5sum -c md5sums
popd;
echo "################################################################################";
echo "#----------------------Packages Checksum check complete------------------------#";
echo "################################################################################";
sleep 5;

# give file ownership to lfs
echo "################################################################################";
echo "#------------------Change sources folders file permissions---------------------#";
echo "################################################################################";
chown root:root $LFS/sources/*;
echo "################################################################################";
echo "#-------------Change sources folders file permissions complete-----------------#";
echo "################################################################################";