# Extract package 
cd $LFS/sources;
tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep libstdc | grep tar )
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/libstdc" | tar)
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/libstdc")
# create a build dir
mkdir -v build;
sleep 2;
cd build;
# Prepare package for compilation:
../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --build=$(../config.guess)      \
    --prefix=/usr                   \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/13.2.0;
# make package
time make;
sleep 2;

# install package
make DESTDIR=$LFS install;
sleep 2;
# Remove the libtool archive files because they are harmful for cross-compilation:
rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la;
# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/libstdc")