mkdir -pv $LFS;
sleep 2;
mount -v -t ext4 /dev/<xxx> $LFS;
sleep 2;
mkdir -pv $LFS;
sleep 2;
mount -v -t ext4 /dev/<xxx> $LFS;
sleep 2;
mkdir -v $LFS/home;
sleep 2;
mount -v -t ext4 /dev/<yyy> $LFS/home;
sleep 2;
# If you are using a swap partition, 
# ensure that it is enabled using the swapon command:

/sbin/swapon -v /dev/<zzz>