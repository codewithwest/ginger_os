# GingerOS – Build Environment Guide (Infrastructure Layer)

This document provides the setup instructions for the host environment where GingerOS is built. This is the "Infrastructure Layer" that supports our automated build scripts.

## 1. Physical/Virtual Host Requirement
GingerOS is designed to be built inside a **Virtual Machine (VM)** to protect your main operating system.

*   **Virtualization**: QEMU/KVM (Recommended), VirtualBox, or VMware.
*   **Host OS**: Ubuntu 24.04 LTS (Recommended) or any modern Linux.
*   **Resources**: 4+ Cores, 8GB+ RAM, 50GB+ Disk.

## 2. Infrastructure Setup (One-Time)
Run these commands on your host system:

```bash
# Install QEMU and utilities
sudo apt update
sudo apt install -y qemu-system-x86 qemu-utils libvirt-daemon-system virt-manager
```

## 3. The GingerOS Automated Workflow
Once your VM is running, do NOT perform manual LFS steps. Use the scripted workflow:

### Step A: Script Initialization (As Root)
Copy the `ginger_os` project folder into your VM environment and run:
```bash
cd ginger_os
sudo ./scripts/setup-host.sh
```
*This handles user creation, directory hierarchy ($LFS), and permission hardening.*

### Step B: Source Acquisition
```bash
./scripts/download.sh
```
*Fetches all LFS 12.4 packages and verifies MD5 sums according to the book.*

### Step C: Disk Preparation
```bash
sudo ./scripts/prepare-image.sh
```
*Creates the virtual 20GB system disk and mounts it at `/mnt/lfs`.*

### Step D: The Build (As 'lfs' User)
```bash
sudo su - lfs
cd [path-to-ginger_os]
./build.sh
```
*Executes Phase 1 (Toolchain) and Phase 2 (Temp Tools) automatically.*

### Step E: The Chroot Phase
Exit the `lfs` shell and run:
```bash
sudo ./chroot.sh
# Then inside chroot:
for script in /scripts/phase3-system/*.sh; do bash "$script"; done
```

## 4. Why This Configuration?
*   **Isolation**: Every build happens in a loopback image or dedicated disk, ensuring no files touch your host's `/usr` or `/etc`.
*   **Reproducibility**: Environment variables are managed by `config/env.sh`, not manual Bash profiles.
*   **Safety**: Root is only used for mounting and user creation; the build itself runs as an unprivileged user.

---
*Refer to `WORKFLOW.md` for detailed per-script explanations.*
