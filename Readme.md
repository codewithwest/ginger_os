# Ginger OS from scratch

## Preparing for the Build
### Chapter 2. Preparing the Host System
- version-check.sh
### 2.4. Creating a New Partition
#### Todo
### 2.5. Creating a File System on the Partition

### 2.7. Mounting the New Partition
- mounting_new_partitions.sh
### 2.6. Setting The $LFS Variable
- setting-up-local-var.sh
### Chapter 3. Packages and Patches
- prepare_sources_dir.sh
### 4.3. Adding the LFS User
- adding_lfs_user.sh
### 4.4. Setting Up the Environment
- setting_up_env.sh
## Part III. Building the LFS Cross Toolchain and Temporary Tools
### Chapter 5. Compiling a Cross-Toolchain
### 5.2. Binutils-2.42 - Pass 1
- binutils.sh
### 5.3. GCC-13.2.0 - Pass 1
- gcc_pass1.sh
### 5.4. Linux-6.7.4 API Headers
- linux_h.sh
### 5.5. Glibc-2.39
- glibc.sh
### 5.6. Libstdc++ from GCC-13.2.0
- libstdc.sh

### Chapter 6. Cross Compiling Temporary Tools
### 6.2. M4-1.4.19
- m4.sh
### 6.3. Ncurses-6.4-20230520
- ncurses.sh
### 6.4. Bash-5.2.21
- bash.sh
### 6.5. Coreutils-9.4
- coreutils.sh
### 6.6. Diffutils-3.10
- diffutils.sh
### 6.7. File-5.45
- file.sh
### 6.8. Findutils-4.9.0
- findutils.sh
### 6.9. Gawk-5.3.0
- gawk.sh
### 6.10. Grep-3.11
- grep.sh
### 6.11. Gzip-1.13
- gzip.sh
### 6.12. Make-4.4.1
- make.sh
### 6.13. Patch-2.7.6
- patch.sh
### 6.14. Sed-4.9
- sed.sh
### 6.15. Tar-1.35
- tar.sh
### 6.16. Xz-5.4.6
- xz.sh
### 6.17. Binutils-2.42 - Pass 2
- binutils_pass2.sh
### 6.18. GCC-13.2.0 - Pass 2
- gcc_pass2.sh
## Chapter 7. Entering Chroot and Building Additional Temporary Tools
### 7.2. Changing Ownership