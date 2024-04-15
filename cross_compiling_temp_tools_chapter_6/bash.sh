# Extract package 
cd $LFS/sources;
tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep bash | grep tar )
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/bash" | tar)
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/bash")
# Prepare package for compilation:
./configure --prefix=/usr                      \
            --build=$(sh support/config.guess) \
            --host=$LFS_TGT                    \
            --without-bash-malloc;
# make package
time make;
sleep 2;
# install package
make DESTDIR=$LFS install;
sleep 2;
# Make a link for the programs that use sh for a shell:
ln -sv bash $LFS/bin/sh;
# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/bash")