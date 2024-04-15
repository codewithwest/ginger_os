# Extract package 
cd $LFS/sources;
tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep binutils | grep tar);
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/binutils" | tar);
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/binutils");
# create a build dir
mkdir -v build;
sleep 2;
cd build;
# Prepare package for compilation:
../configure --prefix=$LFS/tools \
             --with-sysroot=$LFS \
             --target=$LFS_TGT   \
             --disable-nls       \
             --enable-gprofng=no \
             --disable-werror    \
             --enable-default-hash-style=gnu;
# make package
time make;
sleep 2;

# install package
make install;
sleep 2;

# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/binutils")