LFS=/mnt/lfs;
# Extract package 
cd $LFS/sources;
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep xz | grep tar);
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/xz" | grep tar);
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/xz");
# Prepare package for compilation:
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --disable-static                  \
            --docdir=/usr/share/doc/xz-5.4.6;
# make package
time make;
sleep 2;
# install package
make DESTDIR=$LFS install;
sleep 2;
# Remove the libtool archive file because it is harmful for cross compilation:
rm -v $LFS/usr/lib/liblzma.la;
# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/xz");