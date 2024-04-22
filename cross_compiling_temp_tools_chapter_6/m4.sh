LFS=/mnt/lfs;
# Extract package 
cd $LFS/sources;
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep m4 | grep tar);
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/m4" | grep tar);
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/m4");
# Prepare package for compilation:
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess);
# make package
time make;
sleep 2;
# install package
make DESTDIR=$LFS install;
sleep 2;
# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/m4");