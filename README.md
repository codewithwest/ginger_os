# GingerOS - Scripted LFS 12.4 Build System

GingerOS is a fully reproducible, automated build system for Linux From Scratch (LFS) version 12.4. It converts the manual instructions of the LFS book into a suite of idempotent shell scripts designed to run in a safe, isolated VM environment.

## 🚀 Quick Start (Automated Pipeline)

The entire build process is now orchestrated by a single, fail-proof script (`ginger_os.sh`) that manages state and resumes automatically if interrupted.

1.  **Run the Build Script**:
    ```bash
    sudo ./ginger_os.sh
    ```
    This script will:
    - Check and install host requirements.
    - Prepare the disk image.
    - Download sources.
    - Set up the environment.
    - Compile the toolchain (Phase 1 & 2).
    - Build the final system (Phase 3).
    - Compile Kernel and GRUB.
    - Cleanup.

## 📋 Step-by-Step Guide & Purpose

The `ginger_os.sh` orchestrator executes the following sequence. Each step is tracked in `.build_state/` to ensure idempotency.

1.  **Clone & Permissions**: Ensures the repository is correctly set up and accessible.
2.  **Prepare Image (`scripts/prepare-image.sh`)**: Creates a 20GB raw disk image, partitions it, formats it (ext4), and mounts it to `$LFS` (/mnt/lfs). **Warning**: This wipes existing images.
3.  **Download Sources (`scripts/download.sh`)**: Fetches all required source tarballs specified in `config/env.sh` into `sources/`.
4.  **Host Setup (`scripts/setup-host.sh`)**: Configures the host environment, adds the `lfs` user, and sets up directory permissions.
5.  **Host Requirements (`scripts/host-requirements-install.sh`)**: Installs necessary packages (bison, gum, etc.) on the host system to allow compilation.
6.  **Version Check (`scripts/version-check.sh`)**: Verifies that the host tools meet LFS 12.4 version requirements.
7.  **Chroot Preparation (`chroot.sh`)**: Mounts virtual kernel filesystems (`/dev`, `/proc`, `/sys`) into the `$LFS` mount point.
8.  **Setup LFS Env (`scripts/setup-lfs-user-env.sh`)**: Configures the `.bashrc` and `.bash_profile` for the `lfs` user to ensure environment variables are loaded.
9.  **Phase 1 - Temporary Toolchain (`scripts/build-phase1.sh`)**: builds the cross-compiler and basic tools (Binutils, GCC, Glibc) strictly as the `lfs` user.
10. **Phase 2 - Permanent Toolchain (`scripts/build-phase2.sh`)**: Builds the intermediate toolchain that will be used inside chroot.
11. **Phase 3 - System Tools (`scripts/build-phase3.sh`)**: The massive build phase. Compiles all base system software (coreutils, bash, etc.) using the new toolchain.
12. **Kernel & Bootloader (`phases4-boot/`)**: Compiles the Linux Kernel (6.16.1) and installs GRUB.
13. **Teardown (`teardown.sh`)**: Safely unmounts all virtual filesystems and the loopback device to finalize the image.

## 📖 Essential Documentation
For the full detailed walkthrough, refer to:
- **[VM_Config.md](./VM_Config.md)**: How to set up your build machine (The "Infrastructure").
- **[WORKFLOW.md](./WORKFLOW.md)**: The step-by-step master sequence for the build scripts.

## 🏗 Project Architecture
- `config/`: Global environment variables and package versions.
- `scripts/`: Modular build scripts for every chapter.
  - `phase1-tools/`: The cross-toolchain.
  - `phase2-tools/`: Temporary tools.
  - `phase3-system/`: The native system software.
  - `phase4-boot/`: Linux Kernel and GRUB bootloader.
- `logs/`: Individual compilation logs for every package.
- `sources/`: All downloaded tarballs (md5 verified).

## 🛡 Design Philosophy
- **Idempotency**: Every script checks for `.built` flags. If a build fails, just fix and restart—it skips what it has already done.
- **Smart Extract**: No more hardcoded version numbers in scripts. The system dynamically matches tarballs (supports `.tar.*` and `.tgz`).
- **Safety**: Builds happen inside a virtual loopback disk image. `teardown.sh` ensures clean unmounting of kernel file systems.
- **Logging**: Detailed per-package output makes troubleshooting simple.

---
Built with pride for the LFS 12.4 ecosystem.
