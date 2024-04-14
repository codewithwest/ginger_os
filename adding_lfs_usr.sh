# add new group user
groupadd lfs;
useradd -s /bin/bash -g lfs -m -k /dev/null lfs;

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
passwd lfs;
1327;
1327;

# Grant lfs full access to all the directories under $LFS by making lfs the owner:

chown -v lfs $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools};
case $(uname -m) in
  x86_64) chown -v lfs $LFS/lib64 ;;
esac;

# Next, start a shell running as user lfs. 
# This can be done by logging in as lfs on a virtual console, or with the following substitute/switch user command:

su - lfs;