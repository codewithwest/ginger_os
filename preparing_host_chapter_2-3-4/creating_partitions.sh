LFS=/mnt/lfs;
# Creating required partitions
# list disks
fdisk -l;
sleep 2;
# wipe the disk
wipefs -a /dev/sda;

echo "################################################################################";
echo "#--------------------Initiating Partition creation-----------------------------#";
echo "################################################################################";
fdisk -l | grep -A5 "sda";
echo "################################################################################";
echo "#---------------------------Creating Boot Partition-----------------------------#";
echo "################################################################################";
sleep 5;
(
echo g # create new gpt partition
# create boot partition
# echo o # Create a new empty DOS partition table
echo n # Add a new partition
echo  # Partition number
echo  # First sector (Accept default: 1)
echo +250M # Last sector (Accept default: varies)
echo w # Write changes
) | sudo fdisk /dev/sda;
sleep 2;
echo "################################################################################";
echo "#------------------------Boot Partition creation complete----------------------#";
echo "################################################################################";
fdisk -l | grep -A5 "sda";
echo "################################################################################";
echo "#---------------------------Creating EFI Partition-----------------------------#";
echo "################################################################################";
sleep 5;
(
# create efi partition
# echo o # Create a new empty DOS partition table
echo n # Add a new partition
echo  
echo   # Partition number
echo   # First sector (Accept default: 1)
echo +250M # Last sector (Accept default: varies)
echo t # format file system to fat32;
echo 
echo 1
echo p
echo w # Write changes
) | sudo fdisk /dev/sda;

echo "################################################################################";
echo "#------------------------EFI Partition creation complete-----------------------#";
echo "################################################################################";
fdisk -l | grep -A5 "sda";
echo "################################################################################";
echo "#---------------------------Creating SWAP Partition----------------------------#";
echo "################################################################################";
sleep 5;
(
# create swap partition
# echo o # Create a new empty DOS partition table
echo n # Add a new partition
echo   # Partition number
echo   # First sector (Accept default: 1)
echo +2G # Last sector (Accept default: varies)
# format file system to fat32
echo t
echo 
echo 19
echo p
echo w # Write changes
) | sudo fdisk /dev/sda;

echo "################################################################################";
echo "#------------------------SWAP Partition creation complete----------------------#";
echo "################################################################################";
fdisk -l | grep -A5 "sda";
echo "################################################################################";
echo "#---------------------------Creating ROOT Partition----------------------------#";
echo "################################################################################";
sleep 5;
(
# create root partition
# echo o # Create a new empty DOS partition table
echo n # Add a new partition
echo   # Partition number
echo   # First sector (Accept default: 1)
echo   # Last sector (Accept default: varies)
echo w # Write changes
# format file system to fat32
) | sudo fdisk /dev/sda;
echo "################################################################################";
echo "#------------------------ROOT Partition creation complete----------------------#";
echo "################################################################################";
fdisk -l | grep -A5 "sda";
echo "################################################################################";
echo "#----------------------Partition creation complete-----------------------------#";
echo "################################################################################";
# view changes
