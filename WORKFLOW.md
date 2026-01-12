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
This phase runs inside the **chroot** environment. It is now fully automated via a single orchestrator.

1.  **Enter and Execute Chroot Build**:
    ```bash
    # Exit 'lfs' shell first
    exit
    # Run the automated Phase 3 orchestrator
    sudo ./chroot.sh "/scripts/build-phase3.sh"
    ```
    *This automatically builds all final system packages in order (Chapter 8).*

## Phase 4: Making it Bootable
While still in chroot:

1.  **Kernel**: `bash /scripts/phase4-boot/01-kernel.sh`
2.  **Bootloader**: `bash /scripts/phase4-boot/02-grub.sh`

## Phase 5: Finalization & Boot
1.  **Cleanup**: `bash /scripts/phase3-system/99-cleanup.sh`
2.  **Exit & Unmount**:
    ```bash
    exit
    sudo ./teardown.sh
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
- Fix the issue (e.g., download a missing file).
- Run the build command again (`./build.sh` or the chroot command).
- The system will skip already completed packages.

### 2. Retrying a Specific Package
If you need to force a rebuild of a single package:
```bash
# As root or ginger
rm /mnt/lfs/var/lib/ginger/gcc-pass1.built
# Then run the build again
```

### 3. Safety Teardown
If the host becomes unstable or you need to unmount the disk safely:
```bash
sudo ./teardown.sh
```
*This ensures all virtual file systems are unlinked before the host is shut down or the disk moved.*
