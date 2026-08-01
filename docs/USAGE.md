# GingerOS — Operations Guide

GingerOS ships two control surfaces for the build engine and a standalone ISO
installer.

## Launching the build engine

```bash
./run.sh
```

`run.sh` starts the FastAPI backend (`server/main.py`, default port `8087`)
and then builds/launches the Go HUD terminal client (`ui/gotui`). The backend
logs to `backend.log`.

Web dashboard (React, served by the backend): <http://127.0.0.1:8087>

## Go HUD (terminal)

| Key | Action |
|-----|--------|
| **TAB** | Switch workspace (Logs / Chat / Debug) |
| **ALT+TAB** | Reverse workspace switch |
| **↑ / ↓** | Scroll |
| **ENTER** | Run / resume selected step |
| **F** | Force-run step (ignore markers) |
| **P** | Toggle parallel Phase 3 builds |
| **A** | Toggle auto-run |
| **X** | Abort current process group |
| **CTRL+S** | Take a snapshot |
| **Q** | Quit (confirm with ENTER) |

## Web dashboard

- **Step pipeline**: select a step to run, force, or reset it.
- **Package list**: per-step package status and selective builds
  (`POST /api/step/{idx}/packages`, `/api/step/{idx}/run?pkg=...`).
- **Auto Protocol**: automatic transition between steps.
- **Core Allocation**: live CPU cores for `make -jN`.
- **Neural Stream**: live log stream over WebSocket.
- **Temporal Diagnostics**: package / phase / total build timers.
- **Snapshots**: take / restore build snapshots.

## ISO installer

Build the ISO and test it:

```bash
./make-iso.sh                 # FORCE_REBUILD=1 to bypass the rootfs cache
./test-installer.sh           # boot ISO in QEMU (test-target.qcow2)
./test-boot.sh                # boot the installed test disk
```

The Go installer (`lfs/iso/installer/main.go`) is a single static binary. It
formats the target, extracts the purged rootfs, fixes `/etc/fstab` with the
real root UUID, creates the user account, and installs GRUB. The ISO boots
to the installer directly (no interactive menu needed on serial console).

## Verification

After installing, boot with `./test-boot.sh` and log in as the user created
during install (`root` password is set at install time):

```bash
systemctl is-system-running
systemctl is-active systemd-networkd systemd-logind dbus
ip addr show eth0
```

## Recovery

- **Abort**: press **X** (kills the whole process group).
- **Resume**: press **ENTER** on the failed step; markers skip completed work.
- **Force**: press **F** on any step.
- **Fresh disk**: re-running step 01 clears build markers — restore phase
  1/2 markers with `sudo bash lfs/restore-phase-markers.sh` if the toolchain
  is already built.
- **Snapshot rollback**: `POST /api/snapshots/restore/{snap_name}` or the
  dashboard snapshot panel.
