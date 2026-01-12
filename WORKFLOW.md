# GingerOS - Standard Build Workflow

This document defines the official sequence for building the GingerOS (LFS 12.4) system.

## Phase 0: Host Setup
Perform these steps on a clean Ubuntu/Debian host (preferably in a VM).

1. **Source Acquisition**:
    ```bash
    cd /opt/ginger_os
    ./scripts/download.sh
    ```
    *Fetches all LFS 12.4 packages and verifies MD5 sums.*

2. **Disk Preparation**:
    ```bash
    sudo ./scripts/prepare-image.sh
    ```
    *Creates the 20GB system disk and mounts it at /mnt/lfs.*

3. **Host Setup**:
    ```bash
    sudo ./scripts/setup-host.sh
    ```
    *Creates the 'lfs' user and copies sources onto the mounted disk.*

## Phase 1 & 2: The Toolchain Construction
This phase is fully automated and runs as the unprivileged `lfs` user.

1.  **Switch User**:
    ```bash
    sudo su - lfs
    ```
2.  **Execute Build**:
    ```bash
    cd /opt/ginger_os
    ./build.sh
    ```
    *Orchestrates chapters 5 and 6 of the LFS book. Progress is stored in `logs/` and `.built` markers.*

## Phase 3: Building the Final System
This phase runs inside the **chroot** environment to ensure absolute isolation.

1.  **Enter Chroot**:
    ```bash
    # Exit 'lfs' shell first
    sudo ./chroot.sh
    ```
2.  **Execute System Build**:
    Run scripts in order using the numerical prefix.
    ```bash
    for f in /scripts/phase3-system/[0-8]*.sh; do
        bash "$f"
    done
    ```
    *This builds the final Linux system (Chapter 8).*

## Phase 4: Making it Bootable
While still in chroot:

1.  **Kernel**: `bash /scripts/phase4-boot/01-kernel.sh`
2.  **Bootloader**: `bash /scripts/phase4-boot/02-grub.sh`

## Phase 5: Finalization & Boot
1.  **Cleanup**: `bash /scripts/phase3-system/99-cleanup.sh`
2.  **Exit & Unmount**:
    ```bash
    exit
    sudo umount -R $LFS
    ```
3.  **Boot the System**:
    ```bash
    ./qemu-run.sh
    ```

---
---
## 🏁 Recovery & Troubleshooting

### 1. Resuming After Failure
If a script fails, don't worry. 
- Fix the issue (e.g., download a missing file or install a host dependency).
- Run `./build.sh` (or the specific script) again. 
- The build will skip already completed packages by checking `/mnt/lfs/var/lib/ginger/`.

### 2. Retrying a Specific Package
If you need to force a rebuild of a single package:
```bash
# As root or ginger
rm /mnt/lfs/var/lib/ginger/gcc-pass1.built
# Then run the build again
```

### 3. Cleaning Up
If you want to start the **entire build** from scratch:
```bash
sudo rm -rf /mnt/lfs/var/lib/ginger/*.built
```
*Note: This does not delete compiled files, just the markers that skip them.*
