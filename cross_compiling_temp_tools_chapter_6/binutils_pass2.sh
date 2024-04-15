# Extract package 
cd $LFS/sources;
tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep binutils | grep tar )
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/binutils" | tar)
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/binutils")
# create a build dir
mkdir -v build;
sleep 2;
cd build;
# Prepare package for compilation:
../configure                   \
    --prefix=/usr              \
    --build=$(../config.guess) \
    --host=$LFS_TGT            \
    --disable-nls              \
    --enable-shared            \
    --enable-gprofng=no        \
    --disable-werror           \
    --enable-64-bit-bfd        \
    --enable-default-hash-style=gnu;
# make package
time make;
sleep 2;

# install package
make DESTDIR=$LFS install;
sleep 2;
# Remove the libtool archive files because they are harmful for cross compilation, 
# and remove unnecessary static libraries:
rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la};
# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/binutils")