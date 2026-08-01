# GingerOS

GingerOS is a Linux distribution built **from scratch** following the
[Linux From Scratch 13.0 (systemd edition)](https://www.linuxfromscratch.org/) book,
produced by a fully automated, host-isolated build system and shipped as a
bootable ISO with a native installer.

- **Base**: LFS 13.0 (systemd edition), glibc 2.43, GCC 15.2.0, Binutils 2.46.0
- **Kernel**: Linux 6.18.10 (`x86_64-lfs-linux-gnu`)
- **Init**: systemd (networkd, logind, journald, dbus)
- **Latest release**: [v1.0.0-stable](docs/releases/v1.0.0-stable.md)

---

## Overview

The project has two independent pipelines:

1. **Build pipeline** — a Python orchestrator (`server/`) drives a 13-step LFS
   build inside an isolated QEMU disk image (`ginger_os.img`) using chroot and
   bind mounts. Zero host pollution: nothing LFS-related is installed on the
   host machine.
2. **ISO pipeline** — `lfs/iso/make-iso.sh` turns the finished LFS disk into a
   bootable installer ISO (`gingeros-installer.iso`) containing a statically
   linked Go installer, a purged rootfs tarball, the kernel, and an initrd.

### Architecture

```
┌─────────────────────────── Host Machine ───────────────────────────┐
│                                                                     │
│   GingerEngine (Python, server/)                                    │
│     ├── TUI: Go HUD (ui/gotui)                                      │
│     ├── Web UI: React dashboard (ui/web, FastAPI backend)           │
│     └── 13 build steps (server/build_steps.py)                      │
│                                                                     │
│   lfs/image/01-prepare-image.sh ──▶ ginger_os.img (raw, 32G)        │
│   lfs/image/02-install-ubuntu.sh ──▶ debootstrap Ubuntu 24.04 base  │
│   chroot + bind-mounts ──▶ phases 1-4 (server + lfs/phase*/*.sh)    │
│                                                                     │
│   lfs/iso/make-iso.sh ──▶ gingeos-installer.iso (grub-mkrescue)     │
└─────────────────────────────────────────────────────────────────────┘
```

## Build pipeline (13 steps)

| # | Step | Script | Phase |
|---|------|--------|-------|
| 01 | Create QEMU Image | `lfs/image/01-prepare-image.sh` | Preparation |
| 02 | Install Ubuntu Base | `lfs/image/02-install-ubuntu.sh` | Preparation |
| 03 | Host Requirements | `lfs/host/03-host-requirements.sh` | Host Setup |
| 04 | Download Sources | `lfs/host/04-download.sh` | Host Setup |
| 05 | Host Environment | `lfs/host/05-setup-host.sh` | Host Setup |
| 06 | Version Check | `lfs/host/06-version-check.sh` | Host Setup |
| 07 | Phase 1 Tools | `lfs/phases/07-build-phase1.sh` | Phase 1 Tools |
| 08 | Phase 2 Tools | `lfs/phases/08-build-phase2.sh` | Phase 2 Tools |
| 09 | Mount Chroot | `lfs/phases/09-chroot-mounts.sh` | Phase 3 System |
| 10 | System Build | `lfs/chroot.sh lfs/phases/10-build-phase3.sh` | Phase 3 System |
| 11 | Kernel Build | `lfs/chroot.sh lfs/phases/11-build-phase4.sh` | Kernel & Boot |
| 12 | Finalize System | `lfs/host/12-finalize-system.sh` | Kernel & Boot |
| 13 | Teardown | `lfs/image/13-teardown.sh` | Kernel & Boot |

Build state is tracked with marker files in `.build_state/` (host) and
`/var/lib/ginger/` (in the image), so any step can be resumed or force-ran
without redoing completed packages.

## ISO pipeline

```
./make-iso.sh                          # build gingeos-installer.iso
FORCE_REBUILD=1 ./make-iso.sh          # ignore cached rootfs + kernel
```

`make-iso.sh`:

1. Mounts `ginger_os.img` (or reuses the cached rootfs tarball + kernel).
2. Applies `lfs/iso/purge-rootfs.py` — a streaming filter that removes
   Ubuntu/build-tree contamination (e.g. `usr/lib/x86_64-linux-gnu`,
   Python, stale systemd units) while preserving genuine LFS artifacts.
3. Builds a minimal initrd with the essential tools, GRUB modules, and
   terminfo.
4. Copies the statically linked Go installer (`lfs/iso/ginger-installer`).
5. Produces a bootable ISO with `grub-mkrescue`.

### Go installer (on the ISO)

The installer is a single static Go binary (`lfs/iso/installer/main.go`) with
no runtime dependencies. It performs 5 steps:

1. **Partitioning** — wipe target, GPT table, ext4 root partition.
2. **Extract Filesystem** — stream the rootfs tarball onto the target.
3. **Hardware Sync** — install the kernel, create merged-`/usr` symlinks,
   and rewrite `/etc/fstab` with the target's real root UUID.
4. **User Setup** — create the user account, set passwords.
5. **Bootloader** — GRUB install, hostname, network config.

Serial console (`console=ttyS0`) is enabled in the installed GRUB config for
headless testing.

## Requirements (build host)

- Ubuntu 24.04 (64-bit), 16 GB+ RAM, ~40 GB free disk
- `qemu-system-x86`, `qemu-utils`, `debootstrap`, `grub-mkrescue`
- Python 3.10+ with `pydantic`, `fastapi`, `uvicorn`, `psutil`, `rich`
- Go toolchain (for the Go HUD and installer)
- Node.js + npm (only for building the React web UI)

## Directory structure

```
server/            Python orchestrator (engine, API, monitors)
lfs/               Build + install logic (host, image, phases, iso)
lfs/iso/installer/ Go installer source
ui/gotui/          Go HUD (terminal UI)
ui/web/            React dashboard (web UI)
config/            Constants + configuration loading
tests/             Python + bash tests
docs/              Documentation + release notes
.build_state/      Internal build markers
sources/           Downloaded LFS tarballs
```

See [docs/WORKFLOW.md](docs/WORKFLOW.md) for the full workflow and
[docs/releases/v1.0.0-stable.md](docs/releases/v1.0.0-stable.md) for the
v1.0.0-stable release notes.
