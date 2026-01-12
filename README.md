# GingerOS - Scripted LFS 12.4 Build System

GingerOS is a fully reproducible, automated build system for Linux From Scratch (LFS) version 12.4. It converts the manual instructions of the LFS book into a suite of idempotent shell scripts designed to run in a safe, isolated VM environment.

## 🚀 Quick Start (Automated Pipeline)

1.  **Prepare Host**: Spin up an Ubuntu VM, copy the repository to `/opt/ginger_os`, and ensure the `lfs` user has ownership.
    ```bash
    sudo mv ginger_os /opt/
    sudo chown -R lfs:lfs /opt/ginger_os
    ```
2.  **Source Acquisition**:
    ```bash
    cd /opt/ginger_os
    ./scripts/download.sh
    ```
    *Note: GingerOS uses "Smart Extract"—it will automatically find the correct versioned tarball in your sources folder.*
3.  **Disk Preparation**:
    ```bash
    sudo ./scripts/prepare-image.sh
    ```
4.  **Host Setup**:
    ```bash
    sudo ./scripts/setup-host.sh
    ```
5.  **Build Toolchain (As 'lfs' User)**:
    ```bash
    sudo su - lfs
    cd /opt/ginger_os
    ./build.sh
    ```
6.  **Build Final System (Inside Chroot)**:
    ```bash
    exit                              # Back to root
    sudo ./chroot.sh "/scripts/build-phase3.sh"
    ```
7.  **Safe Cleanup**:
    ```bash
    sudo ./teardown.sh                # Safely unmount virtual systems
    ```

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
