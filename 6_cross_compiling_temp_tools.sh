#!/bin/bash
echo "################################################################################";
echo "#--------------------------Setting LFS variable--------------------------------#";
echo "################################################################################";
echo;echo;echo;
LFS=/mnt/lfs;
sleep 5;
#!/bin/bash
echo "################################################################################";
echo "#--------------------------Creating Debug Directory---------------------------#-";
echo "################################################################################";
echo;echo;echo;
mkdir -pv $LFS/sources/debug_logs/chapter_6/;
echo "################################################################################";
echo "#-------------------Chapter 6. Cross Compiling Temporary Tools-----------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#-----------------------------M4-1.4.19----------------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/m4.sh >> $LFS/sources/debug_logs/chapter_6/m4.log
echo "################################################################################";
echo "#-----------------------M4-1.4.19 Completed------------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#--------------------------Ncurses-6.4-20230520--------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/ncurses.sh >> $LFS/sources/debug_logs/chapter_6/ncurses.log
echo "################################################################################";
echo "#-----------------------Ncurses-6.4-20230520 Completed-------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#-------------------------------Bash-5.2.21------------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/bash.sh >> $LFS/sources/debug_logs/chapter_6/bash.log
echo "################################################################################";
echo "#-----------------------------Bash-5.2.21 Completed----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#----------------------------- Coreutils-9.4-----------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/coreutils.sh >>  $LFS/sources/debug_logs/chapter_6/coreutils.log
echo "################################################################################";
echo "#------------------------Coreutils-9.4 Completed-------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#-----------------------------Diffutils-3.10-----------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/diffutils.sh >> $LFS/sources/debug_logs/chapter_6/diffutils.log
echo "################################################################################";
echo "#----------------------------Diffutils-3.10 Completed--------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#-------------------------------File-5.45--------------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/file.sh >> $LFS/sources/debug_logs/chapter_6/file.log
echo "################################################################################";
echo "#------------------------------File-5.45 Completed-----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#-----------------------------Findutils-4.9.0----------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/findutils.sh >> $LFS/sources/debug_logs/chapter_6/findutils.log
echo "################################################################################";
echo "#----------------------------Findutils-4.9.0 Completed-------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#-------------------------------Gawk-5.3.0-------------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/gawk.sh >> $LFS/sources/debug_logs/chapter_6/gawk.log
echo "################################################################################";
echo "#------------------------------Gawk-5.3.0 Completed----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#-------------------------------Grep-3.11--------------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/grep.sh >> $LFS/sources/debug_logs/chapter_6/grep.log
echo "################################################################################";
echo "#------------------------------Grep-3.11 Completed-----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#--------------------------------Gzip-1.13-------------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/gzip.sh >> $LFS/sources/debug_logs/chapter_6/gzip.log
echo "################################################################################";
echo "#-------------------------------Gzip-1.13 Completed----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#--------------------------------Make-4.4.1------------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/make.sh >> $LFS/sources/debug_logs/chapter_6/make.log
echo "################################################################################";
echo "#-------------------------------Make-4.4.1 Completed---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#--------------------------------Patch-2.7.6-----------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/patch.sh >> $LFS/sources/debug_logs/chapter_6/patch.log
echo "################################################################################";
echo "#-------------------------------Patch-2.7.6 Completed--------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#--------------------------------Sed-4.9---------------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/sed.sh >> $LFS/sources/debug_logs/chapter_6/sed.log
echo "################################################################################";
echo "#-------------------------------Sed-4.9 Completed------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#-------------------------------Tar-1.35---------------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/tar.sh >> $LFS/sources/debug_logs/chapter_6/tar.log
echo "################################################################################";
echo "#-------------------------------Tar-1.35 Completed-----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#--------------------------------Xz-5.4.6--------------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/xz.sh >> $LFS/sources/debug_logs/chapter_6/xz.log
echo "################################################################################";
echo "#--------------------------------Xz-5.4.6 Completed----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#-------------------------Binutils-2.42 - Pass 2-------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/binutils_pass2.sh >> $LFS/sources/debug_logs/chapter_5/binutils_pass2.sh.log
echo "################################################################################";
echo "#---------------------Binutils-2.42 - Pass 2 Completed-------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;
echo "################################################################################";
echo "#---------------------------GCC-13.2.0 - Pass 2--------------------------------#";
echo "################################################################################";
bash ./cross_compiling_temp_tools_chapter_6/gcc_pass2.sh >> $LFS/sources/debug_logs/chapter_5/gcc_p2.log
echo "################################################################################";
echo "#-----------------------GCC-13.2.0 - Pass 2 Completed--------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 5;

echo "################################################################################";
echo "#-------------Chapter 6. Cross Compiling Temporary Tools Complete--------------#";
echo "################################################################################";

