#!/bin/bash
echo "################################################################################";
echo "#--------------------------Setting LFS variable--------------------------------#";
echo "################################################################################";
echo;echo;echo;
LFS=/mnt/lfs;
sleep 5;
echo "################################################################################";
echo "#-----------------------4.4. Setting Up the Environment------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

echo "################################################################################";
echo "#-------------The new instance of the shell is a non-login shell---------------#";
echo "#-------------------which does not read, and execute,--------------------------#";
echo "#-----------the contents of the /etc/profile or .bash_profile files,-----------#";
echo "#-----------but rather reads, and executes, the .bashrc file instead.----------#";
echo "#---------------------------Create the .bashrc file now:-----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
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
echo "################################################################################";
echo "#-Several com distros add an undocumented instantiation of /etc/bash.bashrc to-#";
echo "#--the init of bash. This file has the potential to modify the lfs user's env--#";
echo "#-in ways tht can affect the building of critical LFS pkgs. mk sr the lfs usrs-#";
echo "#---env is clean, check for the presence of /etc/bash.bashrc and, if present,--#";
echo "#--------------move it out of the way. As the root user, run:------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
[ ! -e /etc/bash.bashrc ] || mv -v /etc/bash.bashrc /etc/bash.bashrc.NOUSE;
echo "################################################################################";
echo "#-------------------------refresh the bash profile-----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
source ~/.bash_profile;
