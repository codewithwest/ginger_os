#!/bin/bash

source ./scripts/common.sh

# Clone the GingerOS repository
log "INFO" "Cloning GingerOS repository to /opt/ginger_os..."
git clone https://github.com/codewithwest/ginger_os.git /opt/ginger_os

# change into the repository directory
log "INFO" "Changing directory to /opt/ginger_os..."
cd /opt/ginger_os

# make the repo all access readable
log "INFO" "Setting permissions..."
chmod -R 777 /opt/ginger_os

# prepare the image
log "INFO" "Preparing the image..."
bash ./scripts/prepare-image.sh

# download the sources
log "INFO" "Downloading sources..."
bash ./scripts/download.sh

# setup the host
log "INFO" "Setting up host..."
bash ./scripts/host-setup.sh

# update the directory
log "INFO" "Updating directory..."
bash ./scripts/update-dir.sh

# update the host packages
log "INFO" "Installing host requirements..."
bash ./scripts/host-requirements-install.sh

log "INFO" "Running version check..."
bash ./scripts/version-check.sh

# run chroot
log "INFO" "Entering chroot environment..."
bash ./scripts/chroot.sh
log "INFO" "Mounting lfs drive file..."
sudo mount /dev/loop0p1 /mnt/lfs
log "INFO" "Checking mounted drive..."
df -h /mnt/lfs
log "INFO" "Creating directories..."
sudo mkdir -p /mnt/lfs/{dev,proc,sys,run}
log "INFO" "Mounting directories..."
sudo mount --bind /dev      /mnt/lfs/dev
sudo mount --bind /dev/pts  /mnt/lfs/dev/pts
sudo mount -t proc proc     /mnt/lfs/proc
sudo mount -t sysfs sysfs   /mnt/lfs/sys
sudo mount -t tmpfs tmpfs   /mnt/lfs/run


# this is how you supposed to run the scripts as lfs user
# create a function that takes a param and executes
run_as_lfs() {
    sudo chroot "$MOUNT_POINT" /bin/bash -c "$1"
}

# run the scripts as lfs user
log "INFO" "Setting up LFS user environment..."
run_as_lfs "bash ./scripts/setup-ls-user-env"

# begin LFS Chapter 5 (temporary toolchain)
log "INFO" "Starting Phase 1 (Temporary Toolchain)..."
run_as_lfs "bash ./build-phase1.sh"

# begin LFS Chapter 6 (permanent toolchain)
log "INFO" "Starting Phase 2 (Permanent Toolchain)..."
run_as_lfs "bash ./build-phase2.sh"

# begin LFS Chapter 7 (system tools)
log "INFO" "Starting Phase 3 (System Tools)..."
run_as_lfs "bash ./build-phase3.sh"

# compile the kernel
log "INFO" "Compiling the kernel..."
run_as_lfs "bash ./scripts/phase4-boot/01-kernel.sh"

# compile the boot loader
log "INFO" "Compiling and installing GRUB..."
bash ./scripts/phase4-boot/02-grub.sh

# teardown the chroot
log "INFO" "Tearing down chroot..."
bash ./scripts/teardown.sh


