# Extract package 
cd $LFS/sources;
tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep coreutils | grep tar );
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/coreutils" | tar);
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/coreutils");
# Prepare package for compilation:
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime;
# make package
time make;
sleep 2;
# install package
make DESTDIR=$LFS install;
sleep 2;
# Move programs to their final expected locations. Although this is not necessary in 
# this temporary environment, we must do so because some programs hardcode executable locations:

mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin;
mkdir -pv $LFS/usr/share/man/man8;
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8;
sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8;
# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/coreutils")