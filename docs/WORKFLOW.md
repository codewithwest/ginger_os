# GingerOS — Build & Install Workflow

This document defines the official workflow for building GingerOS (LFS 13.0,
systemd edition) and producing/installing the release ISO.

## Prerequisites

- Ubuntu 24.04 (64-bit) build host, 16 GB+ RAM, ~40 GB free disk
- `qemu-system-x86 qemu-utils debootstrap grub-mkrescue`
- Python venv with the project dependencies (see `pyproject.toml` / `.venv`)
- Go toolchain, Node.js + npm (for the UIs)

Clone the repository and set up permissions so the `lfs` user and the build
scripts can read the tree:

```bash
git clone https://github.com/codewithwest/ginger_os.git /opt/ginger_os
cd /opt/ginger_os
sudo chown -R "$USER:lfs" /opt/ginger_os
chmod -R 775 /opt/ginger_os
git config --global --add safe.directory /opt/ginger_os
```

## Stage 1 — Build the LFS system (orchestrator)

Launch the orchestrator (FastAPI backend + Go HUD):

```bash
./run.sh
```

The HUD exposes the full 13-step pipeline. Press **`a`** to auto-run all
steps or **`ENTER`** to step through them. The Web dashboard is available at
<http://127.0.0.1:8087>.

| # | Step | Description |
|---|------|-------------|
| 01 | Create QEMU Image | Creates `ginger_os.img` and mounts it |
| 02 | Install Ubuntu Base | `debootstrap` Ubuntu 24.04 base into the disk |
| 03 | Host Requirements | Installs build deps inside the container |
| 04 | Download Sources | Downloads all LFS 13.0 source tarballs |
| 05 | Host Environment | Directory layout, `lfs` user, merged-usr setup |
| 06 | Version Check | Verifies host tool versions |
| 07 | Phase 1 Tools | Cross toolchain (Binutils, GCC, Glibc pass 1) |
| 08 | Phase 2 Tools | Remaining cross-compiled temporary tools |
| 09 | Mount Chroot | Mounts `/proc`, `/sys`, `/dev` for the LFS chroot |
| 10 | System Build | Compiles the final system packages (LFS ch. 8) |
| 11 | Kernel Build | Linux 6.18.10 kernel + GRUB |
| 12 | Finalize System | fstab, hostname, boot config |
| 13 | Teardown | Unmounts and detaches the loop device |

State markers in `.build_state/` (host) and `/var/lib/ginger/` (image) let the
orchestrator skip completed packages and resume after failures. Use **`F`** to
force a step or **`P`** to toggle parallel Phase 3 builds (experimental).

## Stage 2 — Produce the installer ISO

When the build finishes, `ginger_os.img` is a bootable LFS system. To ship it
as a distributable ISO:

```bash
./make-iso.sh                # reuse cached rootfs + kernel if present
FORCE_REBUILD=1 ./make-iso.sh
```

The ISO build:

1. Mounts `ginger_os.img` and creates `gingeros-lfs-rootfs.tar.gz` (cached).
2. Runs `lfs/iso/purge-rootfs.py` to strip Ubuntu/build-tree contamination.
3. Assembles a minimal initrd (essential tools, GRUB modules, terminfo).
4. Bundles the static Go installer (`lfs/iso/ginger-installer`).
5. Produces `gingeros-installer.iso` via `grub-mkrescue`.

## Stage 3 — Install from the ISO

Test the installer in QEMU:

```bash
./test-installer.sh          # boots the ISO against test-target.qcow2
```

The Go installer runs 5 steps: **Partitioning → Extract Filesystem →
Hardware Sync → User Setup → Bootloader**. It writes `/etc/fstab` with the
target's real root UUID, so the installed system boots cleanly.

## Stage 4 — Boot & verify the installed system

```bash
./test-boot.sh               # boot test-target.qcow2 (installed system)
./qemu-run.sh                # boot the build disk ginger_os.img directly
```

On the installed system (`ginger` / password set during install):

```bash
systemctl is-system-running      # expect "running"
systemctl is-active systemd-networkd systemd-logind dbus
ip addr show eth0                # expect DHCP 10.0.2.15/24
```

## Recovery & troubleshooting

- **Resume after failure**: fix the issue and press **`ENTER`** in the HUD;
  completed packages are skipped via markers.
- **Force a step**: highlight it and press **`F`**.
- **Reset a step marker**: `sudo rm .build_state/<step-id>.built`.
- **Fresh disk wipe**: re-running step 01 clears all `.build_state` markers —
  re-run the phases you need after it (see `lfs/restore-phase-markers.sh`).
- **Chroot mounts lost**: step 09 auto-recovers `/proc`, `/sys`, `/dev`.
- **ISO contains stale rootfs**: rebuild with `FORCE_REBUILD=1`.
