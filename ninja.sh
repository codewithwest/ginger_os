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
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep grep | grep tar);
echo "################################################################################";
echo "#---------------------------Extracting ninja package------------------------#";
echo "################################################################################";
echo;echo;echo;
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/ninja" | grep ".tar");
echo "################################################################################";
echo "#--------------------Extracting binutils archive complete----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#----------------------------Change into ninja dir--------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/ninja");
pwd;
sleep 2;
echo "################################################################################";
echo "#------------------------------Configure tool----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#---------------------Set the environment variable NINJAJOBS-------------------#";
echo "################################################################################";
echo;echo;echo;
export NINJAJOBS=4;
echo "################################################################################";
echo "#--------------make ninja recognize the environment variable NINJAJOBS---------#";
echo "################################################################################";
echo;echo;echo;
sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc;
sleep 2;
echo "################################################################################";
echo "#-------------------------Configure tool completed-----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#------------------------------------Make tool---------------------------------#";
echo "################################################################################";
echo;echo;echo;
python3 configure.py --bootstrap;
echo "################################################################################";
echo "#---------------------------Make tool complete---------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#------------------------------Install tool------------------------------------#";
echo "################################################################################";
echo;echo;echo;
install -vm755 ninja /usr/bin/;
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja;
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja;
echo "################################################################################";
echo "#------------------------------Install tool complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#----------------------------------Clean Up -----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/ninja");
echo "################################################################################";
echo "#--------------------------Clean Up Complete-----------------------------------#";
echo "################################################################################";
echo;echo;echo;