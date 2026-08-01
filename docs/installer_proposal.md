> **STATUS: SUPERSEDED (v1.0.0-stable)**
> This proposal was **not adopted as written**. Instead of Python, the installer
> was implemented as a **single statically linked Go binary**
> (`lfs/iso/installer/main.go` → `lfs/iso/ginger-installer`), which avoids any
> Python/runtime dependency on the ISO and on the target during installation.
> The architecture goals below (robust error handling, hardware-aware
> partitioning, native UI) were carried over into the Go implementation. See
> [releases/v1.0.0-stable.md](releases/v1.0.0-stable.md) and the README for the
> current installer design. This document is kept for historical reference.

# Proposal: GingerOS Python-Based Professional Installer

## 🎯 Executive Summary
While the current bash-based installer provides a functional and visually appealing experience, it is inherently limited by shell scripting constraints. We propose a native Python-based installer to provide a robust, hardware-aware, and premium installation experience.

## 🚀 Why Python?

### 1. Robust Error Handling
Bash is notoriously difficult to debug and handle complex failure states (e.g., partial partition table writes). Python's `try...except` blocks and structured logging provide much higher system reliability.

### 2. Advanced Hardware Detection
Using `pyudev` or `/proc` parsing in Python allows the installer to:
- Automatically identify the fastest disk (NVMe vs SATA).
- Detect UEFI vs Legacy BIOS modes securely.
- Estimate installation time based on disk I/O performance.

### 3. Premium UI/UX (`rich`)
The current `ui.sh` is impressive but hard to maintain. A Python installer using the `rich` library can offer:
- Dynamic layout engines that adapt to any screen size.
- More complex interactive elements (scrolling lists, multi-select menu).
- Progress bars that track multiple sub-processes simultaneously.

### 4. Code Reuse
Since GingerOS already uses Python for the build engine (`engine.py`), we can share logic for:
- Logging and Telemetry.
- Configuration parsing (`ginger.conf`).
- Validation of root filesystem integrity.

## 🏗️ Proposed Architecture

- **Engine**: A pure-Python module that orchestrates `parted`, `mkfs`, and `tar`.
- **UI**: A `rich`-driven TUI that mirrors the aesthetic of the current `GingerOS` build engine.
- **Payload**: The `gingeros-base-rootfs.tar.gz` remains as the primary deployment target.

## 📅 Path Forward
1.  Verify the current bash installer using `test-iso.sh`.
2.  Once GingerOS v1.2.4 (stable) is reached, begin prototyping the Python Installer for the v1.5.0 "Professional" release.

---

## ✅ Resolution (v1.0.0-stable)

Delivered as a Go installer instead:

- **Single static binary** (`ginger-installer`) — no Python, `rich`, or runtime
  deps on the ISO or target.
- **5 steps**: Partitioning → Extract Filesystem → Hardware Sync → User Setup →
  Bootloader.
- **Hardware Sync** writes the target's real root UUID into `/etc/fstab`
  (fixing a first-boot `systemd-remount-fs` failure), installs the kernel, and
  creates merged-`/usr` symlinks.
- The bash `installer.sh` remains in the ISO only as a mount-presence marker;
  the Go binary does the actual installation.
