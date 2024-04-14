# Extract package 
cd $LFS/sources;
tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep package_name | grep);
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/package_name" | tar);
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/package_name");
# create a build dir
mkdir -v build;
sleep 2;
cd build;
# make package
time make;
# install package
make install;

# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/package_name");