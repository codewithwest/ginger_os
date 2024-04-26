#!/bin/bash
echo "################################################################################";
echo "#--------------------------Setting LFS variable--------------------------------#";
echo "################################################################################";
echo;echo;echo;
LFS=/mnt/lfs;
sleep 5;
# Create the required directory layout by issuing the following commands as root:
echo "################################################################################";
echo "#------------------Create the required directory layout------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}

for i in bin lib sbin; do
  ln -sv usr/$i $LFS/$i
done

case $(uname -m) in
  x86_64) mkdir -pv $LFS/lib64 ;;
esac

echo "################################################################################";
echo "#--------------Create the required directory layout complete-------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
# This cross-compiler will be installed in a special directory, to separate it from the 
# other programs. Still acting as root, create that directory with this command:
echo "################################################################################";
echo "#-------------------------------Create tools dir-------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
mkdir -pv $LFS/tools
echo "################################################################################";
echo "#--------------------------Create tools dir complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
# add new group user
echo "################################################################################";
echo "#--------------------------Create group user lfs-------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
groupadd lfs;
echo "################################################################################";
echo "#---------------------Create group user lfs complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#--------------------------------Add user lfs----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
useradd -s /bin/bash -g lfs -m -k /dev/null lfs;
echo "################################################################################";
echo "#---------------------------Add user lfs complete------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
# This is what the command line options mean:

## -s /bin/bash
# This makes bash the default shell for user lfs.

## -g lfs
# This option adds user lfs to group lfs.

## -m
# This creates a home directory for lfs.

## -k /dev/null
# This parameter prevents possible copying of files from a skeleton directory (the default is /etc/skel) by changing the input location to the special null device.

## lfs
# This is the name of the new user.

# Create passwd for the user
echo "################################################################################";
echo "#--------------------------Create lfs user passwd------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
(
  echo dummy
  echo dummy
) | passwd lfs;

echo "################################################################################";
echo "#-----------------Create lfs user passwd complete------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "lfs user password is dummy";
echo;echo;echo;
sleep 5;
# Grant lfs full access to all the directories under $LFS by making lfs the owner:
echo "################################################################################";
echo "#-----------------Grant lfs user control to allrequired files------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
chown -v lfs $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools};
sleep 2;
case $(uname -m) in
  x86_64) chown -v lfs $LFS/lib64 ;;
esac;
echo "################################################################################";
echo "#------------Grant lfs user control to allrequired files complete--------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
# Next, start a shell running as user lfs. 
# This can be done by logging in as lfs on a virtual console, or with the following substitute/switch user command:
echo "################################################################################";
echo "#------------------------------Change to lfs user------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
su - lfs;
echo "################################################################################";
echo "#------------------------------In lfs user env---------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;