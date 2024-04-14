# Extract package 
cd $LFS/sources;
tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep linux | grep tar )
tar -xvf $(find "$LFS/sources" -type f | grep -m1 "$LFS/sources/linux" | tar)
sleep 2;
# change into the extracted package
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/linux")
# create a build dir
# make package
make mrproper
sleep 2;
# install package
make headers;
# post install clean up
find usr/include -type f ! -name '*.h' -delete;
sleep 1;
cp -rv usr/include $LFS/usr
sleep 1;
# clean up
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/linux")