LFS=/mnt/lfs;
# Extract package 
cd $LFS/sources;
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep gcc | grep tar);
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/gcc" | grep tar);
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/gcc")

# get the rest of the packages
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/mpfr" | grep tar) \
    --one-top-level=mpfr --strip-components 1
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/gmp" | grep tar) \
    --one-top-level=gmp --strip-components 1
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/mpc" | grep tar) \
    --one-top-level=mpc --strip-components 1
# On x86_64 hosts, set the default directory name for 64-bit libraries to “lib”:
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac;
# Override the building rule of libgcc and libstdc++ headers, to allow building these 
# libraries with POSIX threads support:
sed '/thread_header =/s/@.*@/gthr-posix.h/' \
    -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in;
# create a build dir
mkdir -v build;
sleep 2;
cd build;
sleep 2;

# Prepare package for compilation:
../configure                                       \
    --build=$(../config.guess)                     \
    --host=$LFS_TGT                                \
    --target=$LFS_TGT                              \
    LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc      \
    --prefix=/usr                                  \
    --with-build-sysroot=$LFS                      \
    --enable-default-pie                           \
    --enable-default-ssp                           \
    --disable-nls                                  \
    --disable-multilib                             \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libsanitizer                         \
    --disable-libssp                               \
    --disable-libvtv                               \
    --enable-languages=c,c++;
sleep 2;

# make package
time make;
sleep 2;
# install package
make DESTDIR=$LFS install;
# As a finishing touch, create a utility symlink. 
# Many programs and scripts run cc instead of gcc, which is used to keep programs 
# generic and therefore usable on all kinds of UNIX systems where the GNU C compiler is 
# not always installed. Running cc leaves the system administrator free to 
# decide which C compiler to install:

ln -sv gcc $LFS/usr/bin/cc;
# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/gcc")