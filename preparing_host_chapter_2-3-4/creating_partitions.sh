# Creating required partitions
# list disks
fdisk -l;
sleep 2;
# wipe the disk
wipefs -a /dev/sda;

# create new partitions
fsidk /dev/sda;
# if using UEFI then run command `g` to convert to gpt disk
# create boot partition
n;
# partition no#1
echo;
# first sector
echo;
# last sector
+250M;
# echo y incase of signature question
y;




# create efi partition
n;
# partition no#1
echo;
# first sector
echo;
# last sector
+250M;
# echo y incase of signature question
y;
# format file system to fat32
t;
1;
p;



# create swap partition
n;
# partition no#1
echo;
# first sector
echo;
# last sector
+2G;
# echo y incase of signature question
y;
# format file system to fat32
t;
19;
p;


# create root partition
n;
# partition no#1
echo ;
# first sector
echo ;
# last sector
echo ;
# echo y incase of signature question
y;


# once done write to disk
w;

# view changes

























fdisk -l;
(
echo o # Create a new empty DOS partition table
echo n # Add a new partition
echo p # Primary partition
echo 1 # Partition number
echo   # First sector (Accept default: 1)
echo   # Last sector (Accept default: varies)
echo w # Write changes
) | sudo fdisk
