# GingerOS - Standard Build Workflow

This document defines the official sequence for building the GingerOS (LFS 13.0) system. The process is now **fully automated and containerized** using a QEMU virtual disk and an interactive Python orchestrator.

## 🚀 How to Build

You no longer need to manually switch users or run scripts in sequence. The entire process is managed via the TUI:

```bash
cd /path/to/ginger_os
python3 ginger_os.py
```

Press **`a`** to auto-run all steps, or **`ENTER`** to step through them manually.

---

## The 15-Step Architecture

GingerOS uses a "Docker-Exec" style architecture. It installs a clean Ubuntu base into a virtual disk, and then builds the LFS system _inside_ that isolated container, ensuring zero pollution to your actual host system.

### Stage 1: Virtual Environment Preparation (Host Executed)

1. **01_create_qemu_img**: Creates a raw QEMU virtual disk (`ginger_os.img`) and mounts it to `/mnt/lfs`.
2. **02_install_ubuntu**: Uses `debootstrap` to install a minimal Ubuntu 24.04 base directly into the mounted virtual disk.

_(After Stage 1, all subsequent scripts are executed INSIDE the Ubuntu container using `chroot`)_

### Stage 2: Host Requirements & Sources

3. **03_install_os_base**: Sets up the initial directory structure and the `lfs` user inside the container.
4. **04_setup_downloads**: Downloads all LFS 13.0  source tarballs into `/sources`.
5. **05_host_reqs**: Installs required build dependencies (like `gcc`, `make`, `gawk`) into the Ubuntu container.
6. **06_version_check**: Verifies the container has the correct versions of all build tools.
7. **07_update_dir**: Configures required symlinks (`/bin` -> `/usr/bin`, etc.).

### Stage 3: The Cross-Toolchain (Phase 1 & 2)

8. **08_setup_lfs_env**: Configures the unprivileged `lfs` user environment.
9. **09_phase1_toolchain**: Builds the initial cross-compiler (Binutils, GCC, Glibc).
10. **10_phase2_toolchain**: Builds the remaining cross-compiled tools required for the final system.

### Stage 4: The Final System (Phase 3 & 4)

_At this point, the orchestrator performs a **nested chroot** to enter the pristine LFS system we just built._

11. **11_chroot_mounts**: Mounts virtual kernel filesystems (`/proc`, `/sys`, `/dev`) for the inner LFS environment.
12. **12_phase3_system**: Compiles the final system packages (Chapter 8).
13. **13_kernel**: Builds the Linux kernel and installs GRUB.
14. **14_finalize**: Performs final configuration (fstab, hostname, passwords).

### Stage 5: Teardown & Boot

15. **15_teardown**: Safely unmounts the `ginger_os` bind mounts and the QEMU image.

---

## 🏁 Post-Build: Booting Your OS

Once Step 15 completes, the `ginger_os.img` file is a fully independent, bootable Linux operating system!

You can boot it using the provided QEMU script:

```bash
./qemu-run.sh
```

## 🛠 Recovery & Troubleshooting

### 1. Resuming After Failure

The orchestrator tracks progress using marker files (saved in `.build_state/` and `/var/lib/ginger/`).
If a step fails (e.g., due to a network timeout during download), you can simply fix the issue and press **ENTER** to resume. The system will intelligently skip packages that have already compiled successfully.

### 2. Retrying a Specific Step

If you need to force a rebuild of a specific phase, highlight it in the TUI and press **`f`** (Force Run), or press **`d`** to delete its completion marker.

### 3. Safety Teardown

If you ever need to abort the build and unmount the virtual disk safely from your host, highlight **Step 15 (Teardown)** in the TUI and press **ENTER**, or run:

```bash
sudo ./lfs/image/teardown.sh
```
