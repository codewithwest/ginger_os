# Extract package 
cd $LFS/sources;
tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep gcc | grep tar);
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/gcc" | tar);
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/gcc");

# get the rest of the packages
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/mpfr" | tar) \ 
    --one-top-level=mpfr --strip-components 1
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/gmp" | tar) \
    --one-top-level=gmp --strip-components 1
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/mpc" | tar) \
    --one-top-level=mpc --strip-components 1
# On x86_64 hosts, set the default directory name for 64-bit libraries to “lib”:
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac;

# create a build dir
mkdir -v build;
sleep 2;
cd build;
sleep 2;

# Prepare package for compilation:
../configure                  \
    --target=$LFS_TGT         \
    --prefix=$LFS/tools       \
    --with-glibc-version=2.39 \
    --with-sysroot=$LFS       \
    --with-newlib             \
    --without-headers         \
    --enable-default-pie      \
    --enable-default-ssp      \
    --disable-nls             \
    --disable-shared          \
    --disable-multilib        \
    --disable-threads         \
    --disable-libatomic       \
    --disable-libgomp         \
    --disable-libquadmath     \
    --disable-libssp          \
    --disable-libvtv          \
    --disable-libstdcxx       \
    --enable-languages=c,c++;
sleep 2;

# make package
time make;
sleep 2;
# install package
make install;
# Before clean up
cd ..;
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h;
# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/gcc")