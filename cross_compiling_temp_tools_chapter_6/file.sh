LFS=/mnt/lfs;
# Extract package 
cd $LFS/sources;
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep file | grep tar);
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/file" | grep tar);
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/file");
# create a build dir
mkdir build;
pushd build;
  ../configure --disable-bzlib      \
               --disable-libseccomp \
               --disable-xzlib      \
               --disable-zlib;
  make;
popd;
# Prepare package for compilation:
./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess);
# make package
time make FILE_COMPILE=$(pwd)/build/src/file;
sleep 2;
# install package
make DESTDIR=$LFS install;
sleep 2;
# Remove the libtool archive file because it is harmful for cross compilation:
rm -v $LFS/usr/lib/libmagic.la;
# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/file")