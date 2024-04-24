# Ginger OS from scratch using lfs documentation
## reference: [https://www.linuxfromscratch.org/lfs/downloads/stable-systemd/LFS-BOOK-12.1-systemd-NOCHUNKS.html]

## Stable version 12.1 of lfs

## Preparing for the Build
### Chapter 2. Preparing the Host System
- version-check.sh
### 2.4. Creating a New Partition
-  folder ./preparing_host_chapter_2-3-4
### 2.7. Mounting the New Partition
- mounting_new_partitions.sh
### 2.6. Setting The $LFS Variable
- setting-up-local-var.sh
### Chapter 3. Packages and Patches
- prepare_sources_dir.sh
### 4.3. Adding the LFS User
- adding_lfs_user.sh
### 4.4. Setting Up the Environment
- setting_up_lfs_env.sh
## Part III. Building the LFS Cross Toolchain and Temporary Tools
### Chapter 5. Compiling a Cross-Toolchain
`./compiling_cross_toolchain.sh`
### Chapter 6. Cross Compiling Temporary Tools
`./cross_compiling_temp_tools.sh`
## Chapter 7. Entering Chroot and Building Additional Temporary Tools
### 7.2. Changing Ownership