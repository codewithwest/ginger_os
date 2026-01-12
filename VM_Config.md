## 1. Step 0: Creating the Build VM (The Host)
Before building GingerOS, you need a safe sandbox. Use these settings to create your Ubuntu VM:

### Using QEMU (Command Line)
If you are on a Linux host, run this to create and launch your build environment:
```bash
# 1. Create a 50GB virtual disk for the Ubuntu Host
qemu-img create -f qcow2 ubuntu_host.qcow2 50G

# 2. Launch the installer (Replace with your Ubuntu ISO path)
qemu-system-x86_64 \
    -enable-kvm -m 8G -smp 4 \
    -drive file=ubuntu_host.qcow2,format=qcow2 \
    -cdrom ubuntu-24.04.3-live-server-amd64.iso \
    -boot d -nic user,hostfwd=tcp::2223-:22git sta
```

### Using VirtualBox / VMware
- **OS**: Ubuntu 24.04 64-bit
- **RAM**: 8192 MB (Minimum 4096 MB)
- **CPU**: 4 Cores
- **Disk**: 60 GB (Dynamically allocated)
- **Network**: NAT

---

## 2. Infrastructure Setup (Inside the Ubuntu VM)
Once Ubuntu is installed and you have SSH'd in (or opened the terminal), run:

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
