# Extract package 
cd $LFS/sources;
tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep diffutils | grep tar);
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/diffutils" | tar);
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/diffutils");
# create a build dir
mkdir -v build;
sleep 2;
cd build;
# Prepare package for compilation:
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(./build-aux/config.guess);
# make package
time make;
sleep 2;
# install package
make DESTDIR=$LFS install;
sleep 2;
# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/diffutils");