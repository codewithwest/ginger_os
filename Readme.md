# Project Ginger OS

## Based on Stable version 12.1 of lfs and YouTube playlist

- https://www.linuxfromscratch.org/lfs/downloads/stable-systemd/LFS-BOOK-12.1-systemd-NOCHUNKS.html
- 
## Please Note
- This assumes you building for UFI.
- /dev/sda is your primary drive [Will be clraned and restructured, YOU WILL LOSE DATA].
- This follows the /boot /swap /root partition structure.
- scripts contain execution flow documentation which will also appear in debug folder.
- Scripts are structured per chapter follow guide below
- set LFS variable is ommited because each file sets the variable before all executions.

## Preparing for the Build
# Please enter sudo mode to execute the below
### Chapter 2. Preparing the Host System
`./2_preparing_host_system.sh`
### Chapter 3. Packages and Patches
# Please ensure you have internet connection to run this script
# Check for any checksum errors to check package existance
`./3_packages_and_patches.sh`
### Chapter 4. Final Preparations
`./adding_lfs_usr.sh`
# Please run belows as lfs user `sudo su lfs`
## Part III. Building the LFS Cross Toolchain and Temporary Tools
### Chapter 5. Compiling a Cross-Toolchain
`./5_compiling_cross_toolchain.sh`
### Chapter 6. Cross Compiling Temporary Tools
`./6_cross_compiling_temp_tools.sh`
## Chapter 7. Entering Chroot and Building Additional Temporary Tools