# Extract package 
cd $LFS/sources;
tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep ncurses | grep tar);
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/ncurses" | tar);
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/ncurses");
#First, ensure that gawk is found first during configuration:
sed -i s/mawk// configure;
sleep 2;
# Then, run the following commands to build the “tic” program on the build host:
mkdir build
sleep 2;
pushd build;
  ../configure;
  make -C include;
  make -C progs tic;
popd;
# Prepare package for compilation:
./configure --prefix=/usr                \
            --host=$LFS_TGT              \
            --build=$(./config.guess)    \
            --mandir=/usr/share/man      \
            --with-manpage-format=normal \
            --with-shared                \
            --without-normal             \
            --with-cxx-shared            \
            --without-debug              \
            --without-ada                \
            --disable-stripping          \
            --enable-widec;
# make package
time make;
sleep 2;

# install package
make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install;
ln -sv libncursesw.so $LFS/usr/lib/libncurses.so;
sed -e 's/^#if.*XOPEN.*$/#if 1/' \
    -i $LFS/usr/include/curses.h;
sleep 2;
# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/ncurses");