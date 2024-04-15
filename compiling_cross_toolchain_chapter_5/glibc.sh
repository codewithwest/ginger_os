# Extract package 
cd $LFS/sources;
tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep glibc | grep tar )
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/glibc" | tar)
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/glibc")
#First, create a symbolic link for LSB compliance. Additionally, for x86_64, 
# create a compatibility symbolic link required for proper operation of the 
# dynamic library loader:
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    ;;
esac;
# Some of the Glibc programs use the non-FHS-compliant /var/db directory to store 
# their runtime data. Apply the following patch to make such programs store their 
# runtime data in the FHS-compliant locations:
patch -Np1 -i ../glibc-2.39-fhs-1.patch;
# create a build dir
mkdir -v build;
sleep 2;
cd build;
# Ensure that the ldconfig and sln utilities are installed into /usr/sbin:
echo "rootsbindir=/usr/sbin" > configparms;
# Prepare package for compilation:
../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=4.19               \
      --with-headers=$LFS/usr/include    \
      --disable-nscd                     \
      libc_cv_slibdir=/usr/lib;
# make package
time make;
sleep 2;

# install package
make DESTDIR=$LFS install;
sleep 2;
# Fix a hard coded path to the executable loader in the ldd script:
sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd;
# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/glibc")