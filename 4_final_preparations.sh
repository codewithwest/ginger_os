#!/bin/bash
echo "################################################################################";
echo "#--------------------------Setting LFS variable--------------------------------#";
echo "################################################################################";
echo;echo;echo;
LFS=/mnt/lfs;
sleep 5;
echo "################################################################################";
echo "#--------------------------Creating Debug Directory----------------------------#";
echo "################################################################################";
echo;echo;echo;
mkdir -pv $LFS/sources/debug_logs/chapter_4/;
pwd;
sleep 2;
echo "################################################################################";
echo "#-------------------------Final Preparations-----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 3;
echo "################################################################################";
echo "#-------4.2. Creating a Limited Directory Layout in the LFS Filesystem---------#";
echo "################################################################################";
bash ./final_preparations_chapter_4/adding_lfs_usr.sh >> $LFS/sources/debug_logs/chapter_4/adding_lfs_usr.log
echo "################################################################################";
echo "#-----Creating a Limited Directory Layout in the LFS Filesystem Completed------#";
echo "################################################################################";
sleep 5;
echo "################################################################################";
echo "#--------------------------4.4. Setting Up the Environment---------------------#";
echo "################################################################################";
sleep 2;
echo "################################################################################";
echo "#-----------------------Create new debug log folder----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5; 
mkdir -pv $LFS/sources/debug_logs  # Create new debug_logs folder
sleep 2;
bash ./final_preparations_chapter_4/setting_up_the_env.sh >> $LFS/sources/debug_logs/chapter_4/setting_up_the_env.log
echo "################################################################################";
echo "#------------------------------Creation completed------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#--------------------4. Setting Up the Environment Completed-------------------#";
echo "################################################################################";
sleep 5;
echo "################################################################################";
echo "#--------------------------Packages and Patches Completed----------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;