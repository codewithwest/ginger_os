# GingerOS TODO List

**Status**: v1.0.0-stable released — see
[docs/releases/v1.0.0-stable.md](docs/releases/v1.0.0-stable.md).

---

## ✅ Complete for v1.0.0-stable

### Build engine
- [x] 13-step orchestrated LFS 13.0 (systemd) build with marker-based resume
- [x] Selective single-package builds (API + dashboard)
- [x] Automated mount & chroot recovery
- [x] Snapshot take / restore
- [x] Parallel Phase 3 builds (experimental, `PARALLEL_PHASE3`)
- [x] Process-group isolation for safe aborts
- [x] Subprocess timeout mechanism
- [x] Dry-run mode, telemetry, storage monitor

### Installer / ISO
- [x] Go installer as a single static binary (no Python/runtime deps)
- [x] 5-step install: Partition → Extract → Hardware Sync → User Setup → Bootloader
- [x] Root UUID rewritten into `/etc/fstab` (fixes first-boot
      `systemd-remount-fs` failure)
- [x] `purge-rootfs.py` contamination filter with `KEEP_EXACT` for LFS dbus units
- [x] Rootfs + kernel caching (`FORCE_REBUILD=1` to bypass)

### Stability fixes
- [x] LFS systemd users/groups in `/etc/passwd` + `/etc/group`
      (networkd / logind / journald start correctly)
- [x] `-D libdir=/usr/lib` for kmod / udev / systemd / dbus meson builds
      (LFS libs loadable; dbus gains systemd support)
- [x] Relative merged-`/usr` symlinks in the installer (no host-escape on remove)
- [x] Serial console (`console=ttyS0`) in the installed GRUB config
- [x] Phase 1/2 marker restore helper (`lfs/restore-phase-markers.sh`) for the
      fresh-disk marker wipe

---

## 🔜 Future work (post-v1.0.0)

- [ ] CI: fix shellcheck `scandir` (currently `./scripts`, which does not exist)
- [ ] CI: install `pydantic`/`fastapi` deps for Python engine tests
- [ ] UEFI (Secure Boot) installer support
- [ ] ZFS/btrfs filesystem options in the installer
- [ ] Package cache/mirror selection during install
- [ ] End-to-end install+verify test script in CI

---

## 📝 Historical notes

- **Issue #1–#16**: audit items from 2026-02-13 — all resolved before v1.0.0.
- The Python installer proposal (`docs/installer_proposal.md`) was superseded
  by the Go installer.

**Last Updated**: 2026-08-01
