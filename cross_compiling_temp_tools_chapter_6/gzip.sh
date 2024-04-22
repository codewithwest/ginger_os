LFS=/mnt/lfs;
# Extract package 
cd $LFS/sources;
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep gzip | grep tar);
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/gzip" | grep tar);
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/gzip");
# Prepare package for compilation:
./configure --prefix=/usr --host=$LFS_TGT;
# make package
time make;
sleep 2;
# install package
make DESTDIR=$LFS install;
sleep 2;
# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/gzip");