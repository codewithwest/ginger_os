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
    - Prepare a 20GB sparse disk image.
    - Download and verify all LFS 12.4 sources in parallel.
    - Set up the environment and `lfs` user.
    - Compile the cross-toolchain (Phase 1).
    - Compile the temporary system (Phase 2).
    - Build the final system inside chroot (Phase 3).
    - Compile the Linux Kernel and configure GRUB.
    - Finalize and package the image for deployment.

2.  **Monitor Progress**:
    Logs are stored in `logs/` for every package. If a build fails, the orchestrator will stop. After fixing the issue, just run `sudo ./ginger_os.sh` again to resume.

## 📋 Build Sequence

The `ginger_os.sh` orchestrator executes the following sequence. Each step is tracked in `.build_state/` to ensure idempotency.

1.  **Prepare Image (`scripts/prepare-image.sh`)**: Creates a 20GB raw disk image, partitions it, formats it (ext4), and mounts it to `$LFS`.
2.  **Download Sources (`scripts/download.sh`)**: Fetches all required source tarballs in parallel and verifies MD5 checksums.
3.  **Host Setup**: Installs dependencies and configures the `lfs` user environment.
4.  **Toolchain Phase**: Builds the cross-compiler and temporary tools (Binutils, GCC, Glibc).
5.  **System Phase**: The chroot environment build. Compiles all base system software using the new toolchain.
6.  **Boot Phase**: Compiles the Linux Kernel and sets up the GRUB bootloader.
7.  **Finalization**: Cleans the system, installs generic user accounts, and packages the results.

## 📦 Final Outputs

Once the script completes, you will find the following artifacts in the project root:
- `ginger_os.img`: A 20GB bootable disk image. You can `dd` this to a physical drive or boot it directly in QEMU.
- `gingeros-base-rootfs.tar`: A compressed backup of the entire root filesystem, ready for custom deployment.

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
- **Speed**: Optimized with parallel downloads (`xargs`) and parallel compilation (`MAKEFLAGS`).
- **Safety**: Builds happen inside a virtual loopback disk image to avoid touching your host root.

---
Built with pride for the LFS 12.4 ecosystem.
