# GingerOS - VM Configuration & Setup Guide

This guide explains how to set up the host environment and execute the automated GingerOS build process.

## 1. Creating the Build VM (The Host)
Before building GingerOS, you need a safe sandbox. Use these settings to create your Ubuntu VM:

### Using QEMU (Command Line)
```bash
# 1. Create a 50GB virtual disk for the Ubuntu Host
qemu-img create -f qcow2 ubuntu_host.qcow2 50G

# 2. Launch the installer (Replace with your Ubuntu ISO path)
qemu-system-x86_64 \
    -enable-kvm -m 16G -smp 12 \
    -drive file=ubuntu_host.qcow2,format=qcow2 \
    -cdrom ubuntu-24.04.3-live-server-amd64.iso \
    -boot d -nic user,hostfwd=tcp::2223-:22
```

### Using VirtualBox / VMware
- **OS**: Ubuntu 24.04 64-bit
- **RAM**: 16 GB (Minimum 4096 MB)
- **CPU**: 4 Cores
- **Disk**: 60 GB (Dynamically allocated)

---

## 2. Infrastructure Setup (Inside the Ubuntu VM)
Once Ubuntu is installed, run these commands to prepare the host:

```bash
# 1. Install prerequisites
sudo apt update
sudo apt install -y qemu-system-x86 qemu-utils libvirt-daemon-system

# 2. Clone the repository to /opt (for standard permissions)
sudo git clone https://github.com/codewithwest/ginger_os.git /opt/ginger_os
cd /opt/ginger_os

# 3. Fix permissions for the build users
sudo chown -R $USER:lfs /opt/ginger_os
sudo chmod -R 775 /opt/ginger_os
git config --global --add safe.directory /opt/ginger_os
```

---

## 3. The Automated Build Workflow
GingerOS uses a single master script to manage the entire process.

```bash
# Start the full automated build
sudo ./ginger_os.sh
```

### What `ginger_os.sh` handles:
1.  **Safety Checks**: Validates host tool versions.
2.  **Resource Prep**: Downloads sources (parallel) and prepares the 20GB disk image.
3.  **Cross-Toolchain**: Builds the initial compiler as the `lfs` user.
4.  **Native System**: Enters chroot and builds the full Linux system.
5.  **Finalization**: Compiles the Kernel, installs GRUB, and packages the image.

---

## 4. Recovery & Maintenance

### How to Resume:
If the build fails (e.g., due to a compilation error), simply fix the issue and **run the script again**. It will automatically skip all successfully built packages.

### Safe Exit (Reboot/Shutdown):
If you need to stop the VM or reboot the host, ALWAYS run:
```bash
sudo ./scripts/teardown.sh
```
*This safely unmounts all virtual filesystems and detaches the loopback device.*

### Testing the Result:
To test your new GingerOS image in QEMU:
```bash
qemu-system-x86_64 -enable-kvm -m 2G -drive file=ginger_os.img,format=raw
```

---
*Refer to README.md for project architecture and design philosophy.*
