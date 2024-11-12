#!/bin/bash
echo "################################################################################";
echo "#--------------------------Setting LFS variable--------------------------------#";
echo "################################################################################";
echo;echo;echo;
# LFS=/mnt/lfs;
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
# 
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
../configure --prefix=/usr            \
             LD=ld                    \
             --enable-languages=c,c++ \
             --enable-default-pie     \
             --enable-default-ssp     \
             --enable-host-pie        \
             --disable-multilib       \
             --disable-bootstrap      \
             --disable-fixincludes    \
             --with-system-zlib;

echo "################################################################################";
echo "#--------------------------configure package complete--------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#---------------------------------make package---------------------------------#";
echo "################################################################################";
echo;echo;echo;
time make;
sleep 2;
echo "################################################################################";
echo "#---------------------------------make package complete------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#-------------------------------set the hard limit-----------------------------#";
echo "################################################################################";
# GCC may need more stack space compiling some extremely complex code patterns. As a precaution 
# for the host distros with a tight stack limit, explicitly set the stack size hard limit to 
# infinite. On most host distros (and the final LFS system) the hard limit is infinite by 
# default, but there is no harm done by setting it explicitly. It's not necessary to change 
# the stack size soft limit because GCC will automatically set it to an appropriate value, 
# as long as the value does not exceed the hard limit:
echo;echo;echo;
sleep 1;
ulimit -s -H unlimited;
echo "################################################################################";
echo "#-------------Now remove/fix several known test failures-----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 1;
sed -e '/cpython/d'               -i ../gcc/testsuite/gcc.dg/plugin/plugin.exp
sleep 1;
sed -e 's/no-pic /&-no-pie /'     -i ../gcc/testsuite/gcc.target/i386/pr113689-1.c
sleep 1;
sed -e 's/300000/(1|300000)/'     -i ../libgomp/testsuite/libgomp.c-c++-common/pr109062.c
sleep 1;
sed -e 's/{ target nonpic } //' \
    -e '/GOTPCREL/d'              -i ../gcc/testsuite/gcc.target/i386/fentryname3.c;
sleep 2;
echo "################################################################################";
echo "#-----Test the results as a non-privileged user, but do not stop at errors-----#";
echo "################################################################################";
echo;echo;echo;
sleep 1;   
chown -R tester .
su tester -c "PATH=$PATH make -k check";
sleep 2;
echo "################################################################################";
echo "#--------------To extract a summary of the test suite results, run-------------#";
echo "################################################################################";
echo;echo;echo;
sleep 1;   
chown -R tester .
cat ../contrib/test_summary | grep -A7 Summ;
echo "################################################################################";
echo "#---------------------Configuration and testing complete-----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 1;
echo "################################################################################";
echo "#---------------------------------install package------------------------------#";
echo "################################################################################";
echo;echo;echo;
make install;
echo "################################################################################";
echo "#-------------------------install package complete-----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#---------------------------Grant root ownership-------------------------------#";
echo "################################################################################";
# The GCC build directory is owned by tester now, and the ownership of the installed header 
# directory (and its content) is incorrect. Change the ownership to the root user and group:
echo;echo;echo;
chown -v -R root:root \
    /usr/lib/gcc/$(gcc -dumpmachine)/14.2.0/include{,-fixed};
sleep 5;
echo "################################################################################";
echo "#--------Create a symlink required by the FHS for "historical" reasons---------#";
echo "################################################################################";
echo;echo;echo;
ln -svr /usr/bin/cpp /usr/lib;
sleep 2;
echo "################################################################################";
echo "#---------------------create its man page as a symlink as well-----------------#";
echo "################################################################################";
# Many packages use the name cc to call the C compiler. We've already created cc as a 
# symlink in gcc-pass2, create its man page as a symlink as well:
echo;echo;echo;
ln -sv gcc.1 /usr/share/man/man1/cc.1;
sleep 2;
echo "################################################################################";
echo "#-----Add a compatibility symlink to enable building programs with (LTO)-------#";
echo "################################################################################";
# Link Time Optimization (LTO) is a feature that allows the compiler to optimize the entire
# program at link time. This feature is enabled by passing the -flto option to the compiler.
echo;echo;echo;
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/14.2.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/;
sleep 2;
echo "################################################################################";
echo "#-------------------------performing some sanity checks------------------------#";
echo "################################################################################";
# Now that our final toolchain is in place, it is important to again ensure that compiling 
# and linking will work as expected. We do this by performing some sanity checks.
echo;echo;echo;
echo 'int main(){}' > dummy.c
cc dummy.c -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep ': /lib';
sleep 2;
# There should be no errors, and the output of the last command will be (allowing for 
# platform-specific differences in the dynamic linker name)
echo "expected output: [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]";

#fix the below with reference to this file
echo "################################################################################";
echo "#--------Now make sure that we're set up to use the correct start files--------#";
echo "################################################################################";
# Now that our final toolchain is in place, it is important to again ensure that compiling 
# and linking will work as expected. We do this by performing some sanity checks.
echo;echo;echo;
grep -E -o '/usr/lib.*/S?crt[1in].*succeeded' dummy.log;
sleep 2;
echo "The output of the last command should be:";
echo "/usr/lib/gcc/x86_64-pc-linux-gnu/14.2.0/../../../../lib/Scrt1.o succeeded";
echo "/usr/lib/gcc/x86_64-pc-linux-gnu/14.2.0/../../../../lib/crti.o succeeded";
echo "/usr/lib/gcc/x86_64-pc-linux-gnu/14.2.0/../../../../lib/crtn.o succeeded";

echo "Depending on your machine architecture, the above may differ slightly. \
TheDepending on your machine architecture, the above may differ slightly. The difference \
will be the name of the directory after /usr/lib/gcc. The important thing to look for here \
is that gcc has found all three crt*.o files under the /usr/lib directory.";

echo "################################################################################";
echo "#-------Verify that the compiler is searching for the correct header files-----#";
echo "################################################################################";
echo;echo;echo;
grep -B4 '^ /usr/include' dummy.log;
sleep 2;

echo "This command should return the following output:";
echo "#include <...> search starts here: \n \
 /usr/lib/gcc/x86_64-pc-linux-gnu/14.2.0/include \n \
 /usr/local/include \n \
 /usr/lib/gcc/x86_64-pc-linux-gnu/14.2.0/include-fixed \n \
 /usr/include ";
sleep 2;
echo "Again, the directory named after your target triplet may be different than the \ 
above, depending on your system architecture.";

echo "################################################################################";
echo "#-------------------Verify that the new linker is being used-------------------#";
echo "################################################################################";
echo;echo;echo;
grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'l;
echo "References to paths that have components with '-linux-gnu' should be ignored, but \n \
 otherwise the output of the last command should be:";
echo '\n
SEARCH_DIR("/usr/x86_64-pc-linux-gnu/lib64")  
SEARCH_DIR("/usr/local/lib64") 
SEARCH_DIR("/lib64") 
SEARCH_DIR("/usr/lib64")  
SEARCH_DIR("/usr/x86_64-pc-linux-gnu/lib") 
SEARCH_DIR("/usr/local/lib")  
SEARCH_DIR("/lib") 
SEARCH_DIR("/usr/lib")';
sleep 1;
echo "################################################################################";
echo "#-------------------Verify that we're using the correct libc-------------------#";
echo "################################################################################";
echo;echo;echo;
grep "/lib.*/libc.so.6 " dummy.log;
sleep 2;
echo "The output of the last command should be:";
echo "attempt to open /lib/libc.so.6 succeeded";
echo "If the output is /usr/lib/libc.so.6, then something is wrong and you need to fix it.";
sleep 2;
echo "################################################################################";
echo "#-------------------Verify that we're using the correct dynamic linker---------#";
echo "################################################################################";
echo;echo;echo;
grep found dummy.log;   
sleep 2;
echo "The output of the last command should be:";
echo "found ld-linux-x86-64.so.2 at /lib/ld-linux-x86-64.so.2";
echo "If the output is /usr/lib/ld-linux-x86-64.so.2, then something is wrong and you need to fix it.";
sleep 2;
echo "################################################################################";
echo "#-------Once everything is working correctly, clean up the test files:----------";
echo "################################################################################";
echo;echo;echo;
rm -v dummy.c a.out dummy.log;
sleep 2;
echo "################################################################################";
echo "#---------------clean up the test files complete-------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#-------------------Finally, move a misplaced file:----------------------------#";
echo "################################################################################";
echo;echo;echo;
mkdir -pv /usr/share/gdb/auto-load/usr/lib;
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib;
sleep 2;
echo "################################################################################";
echo "#-------------------move a misplaced file complete-----------------------------#";
echo "################################################################################";
echo;echo;echo;
echo "################################################################################";
echo "#------------------------------- clean up script-------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $LFS/sources;
pwd;
sleep 5;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/gcc")
echo "################################################################################";
echo "#---------------------------clean up script complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;