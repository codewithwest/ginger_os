# GingerOS — VM Configuration & Host Setup

This guide covers the host machine that builds GingerOS and the VMs used to
install/test it.

## 1. Build host (Ubuntu VM)

Recommended: Ubuntu 24.04 64-bit, 16 GB RAM, 12 vCPUs, 60 GB disk (dynamic).

### Using QEMU

```bash
qemu-img create -f qcow2 ubuntu_host.qcow2 50G
qemu-system-x86_64 \
    -enable-kvm -m 16G -smp 12 \
    -drive file=ubuntu_host.qcow2,format=qcow2 \
    -cdrom ubuntu-24.04.3-live-server-amd64.iso \
    -boot d -nic user,hostfwd=tcp::2223-:22
```

### Using VirtualBox / VMware

- **OS**: Ubuntu 24.04 64-bit
- **RAM**: 16 GB (minimum 4 GB)
- **CPU**: 4 cores
- **Disk**: 60 GB (dynamically allocated)

## 2. Host prerequisites

```bash
sudo apt update
sudo apt install -y qemu-system-x86 qemu-utils debootstrap grub-pc-bin
sudo apt install -y python3 python3-venv golang nodejs npm
```

Python dependencies (from the repository root, after cloning):

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt   # or: uv sync
```

## 3. Clone & permissions

```bash
sudo git clone https://github.com/codewithwest/ginger_os.git /opt/ginger_os
cd /opt/ginger_os
sudo chown -R "$USER:lfs" /opt/ginger_os
chmod -R 775 /opt/ginger_os
git config --global --add safe.directory /opt/ginger_os
```

## 4. Build the system

```bash
./run.sh                      # orchestrator (HUD + web UI on :8087)
```

Run all 13 steps, or step through manually. See
[docs/WORKFLOW.md](WORKFLOW.md) for the step reference.

## 5. Build the installer ISO

```bash
./make-iso.sh                 # → gingeos-installer.iso
```

## 6. Test the ISO installer

```bash
./test-installer.sh           # boots ISO; installs to test-target.qcow2
./test-boot.sh                # boots the installed test-target.qcow2
```

`test-installer.sh` forwards host port `2222` to guest SSH (`:22`) for remote
access after boot.

## 7. Boot the raw build image directly

```bash
./qemu-run.sh                 # boots ginger_os.img
```

## Recovery

- If a build fails, fix the issue and press **ENTER** to resume (markers skip
  completed work).
- If the disk image needs a clean reset, re-run step 01, then restore the
  phase 1/2 markers if the toolchain already exists:
  `sudo bash lfs/restore-phase-markers.sh`.
- Always run step 13 (Teardown) before deleting/moving `ginger_os.img`.

_Refer to [README.md](../README.md) for architecture and design philosophy._
