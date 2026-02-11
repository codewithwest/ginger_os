# GingerOS - Cyberpunk Edition (Scripted LFS 12.4)

GingerOS is a fully reproducible, automated, and **visually stunning** build system for Linux From Scratch (LFS) version 12.4. It transforms the manual work of building an OS into a professional dashboard-driven experience.

## 🚀 The Cyberpunk Experience

The entire build, from source collection to final ISO generation, is now driven by a high-tech terminal dashboard with:
- **Neon Blue & Laser Green Theme**: A premium look for a premium system.
- **Unified Roadmaps**: Real-time progress tracking across all 16+ build steps.
- **Idempotent Engine**: Safely resume any step with a single command.
- **Automated ISO Creation**: Build a bootable live environment in seconds.

## 🛠 Usage guide

### 1. Build the System
The main build orchestrator assembles the LFS core toolchain and base system.
```bash
sudo ./ginger_os.sh
```

### 2. Generate the Installer ISO
Once the core is built, package it into a bootable Cyberpunk-themed installer.
```bash
sudo ./make-iso.sh
```

### 3. Test in QEMU
Launch your new system or test the installer immediately.
```bash
./qemu-run.sh
```

## 📋 New Reorganized Architecture

The project has been refactored for maximum reusability and clarity:

- **`scripts/`**: The engine of GingerOS.
  - **`lib/`**: Shared logic for UI themes, disk management, and bash configurations.
  - **`host/`**: Host requirement checks and environment setup.
  - **`image/`**: Raw disk image preparation and teardown.
  - **`iso/`**: Bootable media builders and the professional OS installer.
  - **`phases/`**: Step-by-step LFS compilation phases.
- **`docs/`**: Project documentation, VM configuration, and the official LFS book reference.
- **`sources/`**: Parallel-downloaded terminal tarballs.
- **`logs/`**: Detailed build output for every package.

## 📦 Final Outputs

- `gingeros-installer.iso`: A bootable live environment with a TUI installer.
- `ginger_os.img`: The primary bootable raw image of your new system.
- `gingeros-base-rootfs.tar.gz`: A portable payload that can be deployed to any machine.

## 🛡 Design Philosophy
- **User-Centric**: The installer now handles full user account setup and password configuration.
- **Terminal Excellence**: Custom Bash profiles with Cyberpunk color schemes are applied to the final system.
- **Safety First**: All builds occur in isolated loopback images to protect your host.

---
*Built for speed. Designed for the terminal. GingerOS 12.4.*
