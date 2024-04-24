#!/bin/bash
echo "################################################################################";
echo "#--------------------------Setting LFS variable--------------------------------#";
echo "################################################################################";
echo;echo;echo;
LFS=/mnt/lfs;
sleep 5;
# 4.4. Setting Up the Environment
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF


# The new instance of the shell is a non-login shell, 
# which does not read, and execute, 
# the contents of the /etc/profile or .bash_profile files, 
# but rather reads, and executes, the .bashrc file instead. 
# Create the .bashrc file now:

cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
export MAKEFLAGS=-j$(nproc)
EOF
# Several commercial distributions add an undocumented instantiation of /etc/bash.bashrc to 
# the initialization of bash. This file has the potential to modify the lfs user's environment 
# in ways that can affect the building of critical LFS packages. To make sure the lfs user's 
# environment is clean, check for the presence of /etc/bash.bashrc and, if present, 
# move it out of the way. As the root user, run:
[ ! -e /etc/bash.bashrc ] || mv -v /etc/bash.bashrc /etc/bash.bashrc.NOUSE;
# refresh the bash profile
source ~/.bash_profile;
