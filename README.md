# GingerOS - Scripted LFS Build System

This repository contains a fully reproducible, scripted approach to building a Linux From Scratch (LFS) 12.4 system.

## Directory Structure

- `config/`: Global configuration and environment variables.
- `scripts/`: Implementation of the build phases.
  - `phase1-tools/`: Cross-compiler toolchain.
  - `phase2-tools/`: Temporary tools built using the cross-compiler.
  - `phase3-system/`: The final system build (to be run inside chroot).
  - `phase4-boot/`: Kernel and bootloader configuration.
- `sources/`: Tarballs for all LFS packages.
- `logs/`: Compilation logs for every package.
- `build/`: Temporary extraction and compilation directory.

## Usage

1. **Download Sources**
   ```bash
   ./scripts/download.sh
   ```

2. **Prepare Disk Image**
   ```bash
   ./scripts/prepare-image.sh
   ```

3. **Setup Host**
   ```bash
   sudo ./scripts/setup-host.sh
   ```

4. **Phase 1 & 2 Build**
   Run the main orchestrator (usually as the `lfs` user):
   ```bash
   ./build.sh
   ```

5. **Enter Chroot**
   Phase 3 must be run inside the chroot environment.
   ```bash
   sudo ./chroot.sh
   ```

6. **Run in QEMU**
   ```bash
   ./qemu-run.sh
   ```

## Design Philosophy

- **Idempotency**: Scripts check for `.built` flags in `$LFS/var/lib/ginger` to skip already completed steps.
- **Independence**: Each package has its own script, making debugging and modification easier.
- **Standardization**: Uses standard LFS variables (`LFS`, `LFS_TGT`, `MAKEFLAGS`).
- **Safety**: Mount states and permissions are checked before critical operations.
