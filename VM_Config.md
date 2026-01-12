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

## 5. Safety & Snapshots (The "Save Game" Feature)
Building LFS is a trial-and-error process. Snapshots allow you to "save your game" before a major build phase.

### Creating a Snapshot (VM must be OFF)
Once you have Ubuntu installed and your dependencies ready, create a "Base" snapshot:
```bash
# qemu-img snapshot -c <name> <file>
qemu-img snapshot -c base_system ubuntu_host.qcow2
```

### Listing Snapshots
```bash
qemu-img snapshot -l ubuntu_host.qcow2
```

### Restoring a Snapshot (REVERT)
If a build fails and you want to go back to your "Base" state:
```bash
# qemu-img snapshot -a <name> <file>
qemu-img snapshot -a base_system ubuntu_host.qcow2
```

### Deleting a Snapshot
```bash
qemu-img snapshot -d base_system ubuntu_host.qcow2
```

---

## 6. The GingerOS Automated Workflow
Once your VM is running, do NOT perform manual LFS steps. Use the scripted workflow:

### Step A: Script Initialization (The /opt standard)
To avoid permission issues, we host the project in `/opt`. Run these as your admin user:
```bash
# 1. Clone the repository
sudo git clone https://github.com/codewithwest/ginger_os.git /opt/ginger_os

# 2. Configure ownership for both 'ginger' and 'lfs'
sudo chown -R $USER:lfs /opt/ginger_os
sudo chmod -R 775 /opt/ginger_os
git config --global --add safe.directory /opt/ginger_os

# 3. Initialize host
cd /opt/ginger_os
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
cd /opt/ginger_os
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

## 7. Recovery & Resuming a Build

GingerOS is built with **Idempotency**. Every package script creates a marker once it finishes.

### How to Resume:
If the build fails (e.g., at GCC), simply fix the error and **run the script again**. 
The system will check `/mnt/lfs/var/lib/ginger/` for `.built` files and skip everything that was already successful.

### How to Force a Rebuild:
If you want to re-run a specific package (e.g., to change a config):
1.  Navigate to the status directory: `cd /mnt/lfs/var/lib/ginger/`
2.  Remove the marker: `rm [package_name].built`
3.  Run the script again.

---
*Refer to `WORKFLOW.md` for detailed per-script explanations.*
