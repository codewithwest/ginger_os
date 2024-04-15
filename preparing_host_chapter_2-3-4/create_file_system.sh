# create filesytem for boot
mkfs -v -t ext4 /dev/sda1;
sleep 2;
# create filesytem for boot
mkfs -v -t ext4 /dev/sda4;
sleep 2;
# create efi filesystem
mkfs.vfat -F 32 /dev/sda2;
sleep 2;
# Create swap partition
mkswap /dev/sda3;