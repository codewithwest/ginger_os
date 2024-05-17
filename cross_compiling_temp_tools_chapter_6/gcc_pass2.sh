#!/bin/bash
echo "################################################################################";
echo "#--------------------------Setting LFS variable--------------------------------#";
echo "################################################################################";
echo;echo;echo;
LFS=/mnt/lfs;
sleep 5;
# Extract package 
echo "################################################################################";
echo "#-------------------------Change into sources dir------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $LFS/sources;
pwd;
sleep 5;
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep gcc | grep tar);
echo "################################################################################";
echo "#----------------------------Extract gcc package-------------------------------#";
echo "################################################################################";
echo;echo;echo;
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/gcc" | grep ".tar");
sleep 5;
echo "################################################################################";
echo "#--------------------Extracting gcc package complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# change into the extracted package
echo "################################################################################";
echo "#----------------------------change into gcc dir-------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/gcc");
pwd;
sleep 2;
# get the rest of the packages
echo "################################################################################";
echo "#---------------------------Extract mpfr package-------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/mpfr" | grep tar) \
    --one-top-level=mpfr --strip-components 1
echo "################################################################################";
echo "#---------------------------Extract gmp package--------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/gmp" | grep tar) \
    --one-top-level=gmp --strip-components 1
echo "################################################################################";
echo "#---------------------------Extract mpc package--------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/mpc" | grep tar) \
    --one-top-level=mpc --strip-components 1
echo "################################################################################";
echo "#----------------------Extracting mpfr,gmp,mpc complete------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#-On x86_64 hosts, set the default directory name for 64-bit libraries to lib--#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac;
echo "################################################################################";
echo "#-----set the default directory name for 64-bit libraries to lib complete------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
# Override the building rule of libgcc and libstdc++ headers, to allow building these 
# libraries with POSIX threads support:
sed '/thread_header =/s/@.*@/gthr-posix.h/' \
    -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in;
echo "################################################################################";
echo "#--------------------------create a build dir----------------------------------#";
echo "################################################################################";
echo;echo;echo;
mkdir -v build;
sleep 5;
echo "################################################################################";
echo "#-------------------------change into build dir--------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd build;
sleep 5;
echo "################################################################################";
echo "#-----------------------------configure package--------------------------------#";
echo "################################################################################";
echo;echo;echo;
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
echo "################################################################################";
echo "#--------------------------configure package complete--------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#---------------------------------make package---------------------------------#";
echo "################################################################################";
echo;echo;echo;
time make;
sleep 5;
echo "################################################################################";
echo "#---------------------------------make package complete------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#---------------------------------install package------------------------------#";
echo "################################################################################";
echo;echo;echo;
make DESTDIR=$LFS install;
echo "################################################################################";
echo "#-------------------------install package complete-----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "As a finishing touch, create a utility symlink."
echo "Many programs and scripts run cc instead of gcc, which is used to keep programs" 
echo "generic and therefore usable on all kinds of UNIX systems where the GNU C compiler is" 
echo "not always installed. Running cc leaves the system administrator free to "
echo "decide which C compiler to install":
echo "################################################################################";
echo "#-------------------------------before clean up script-------------------------#";
echo "################################################################################";
echo;echo;echo;
ln -sv gcc $LFS/usr/bin/cc;
sleep 5;
echo "################################################################################";
echo "#------------------------------- clean up script-------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $LFS/sources;
pwd;
sleep 5;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/gcc");
echo "################################################################################";
echo "#---------------------------clean up script complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;