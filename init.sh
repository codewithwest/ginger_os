# Check system compatability
echo "################################################################################";
echo "#--------------------------Preparing for the Build-----------------------------#";
echo "################################################################################";
echo;
echo;
echo "################################################################################";
echo "#------------------------Check system compatibility----------------------------#";
echo "################################################################################";
echo;
echo;
echo "################################################################################";
echo "#---------------------------Running Version Check------------------------------#";
echo "################################################################################";
bash ./preparing_host_chapter_2-3-4/version-check.sh 
# enter sudo mode
echo "################################################################################";
echo "#--------------------------Preparing the Host System---------------------------#";
echo "################################################################################";
echo;echo;echo;
# create new_partitions
bash ./preparing_host_chapter_2-3-4/creating_partitions.sh 
bash ./preparing_host_chapter_2-3-4/create_file_system.sh
bash ./preparing_host_chapter_2-3-4/set_lfs_var.sh
bash ./preparing_host_chapter_2-3-4/mounting_new_partition.sh
bash ./preparing_host_chapter_2-3-4/prepare_sources_dir.sh
bash ./preparing_host_chapter_2-3-4/adding_lfs_usr.sh
echo;echo;echo;
echo "################################################################################";
echo "#----------------------Preparing the Host System Complete----------------------#";
echo "################################################################################";
echo;echo;echo;
echo "If you not already running as lfs user run below command"; 
echo "--------------------------------------------------------------------------------------";
echo "-----------------------------------sudo su lfs----------------------------------------";
echo "--------------------------------------------------------------------------------------";
echo "*************************Now execute the lfs_env as lfs user***************************"
# bash ./lfs_env.sh
