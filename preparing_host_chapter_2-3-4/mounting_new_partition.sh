# create lfs dir
mkdir -pv $LFS;
sleep 2;
# mount root to lfs
mount -v -t ext4 /dev/sda4 $LFS;
sleep 2;
# mount boot to lfs
mkdir -pv $LFS/boot;
sleep 2;
mount -v -t ext4 /dev/sda1 $LFS/boot;
sleep 2;
# If you are using a swap partition, 
# ensure that it is enabled using the swapon command:
/sbin/swapon -v /dev/sda3