# GingerOS — Interactive Build Mode

The Go HUD provides step-by-step execution of the GingerOS build with marker
awareness, package selection, and snapshots.

## Launching

```bash
./run.sh
```

This starts the backend engine (`server/main.py` on port `8087`) and the Go
HUD terminal client. The web dashboard is also available at
<http://127.0.0.1:8087>.

## Controls

| Key | Action |
|-----|--------|
| **ENTER** | Run the selected step (respects markers) |
| **F** | Force-run (ignore markers) |
| **P** | Toggle parallel Phase 3 builds |
| **A** | Toggle auto-run all steps |
| **X** | Abort the current process group |
| **CTRL+S** | Take a build snapshot |
| **TAB** / **ALT+TAB** | Switch between Logs / Chat / Debug workspaces |
| **↑ / ↓** | Scroll the log view |
| **Q** | Quit (press again to confirm) |

## Build steps

| # | Step ID | Name | Phase |
|---|---------|------|-------|
| 01 | 01_create_qemu_img | Create QEMU Image | Preparation |
| 02 | 02_install_ubuntu | Install Ubuntu Base | Preparation |
| 03 | 03_host_requirements | Host Requirements | Host Setup |
| 04 | 04_setup_downloads | Download Sources | Host Setup |
| 05 | 05_host_setup | Host Environment | Host Setup |
| 06 | 06_version_check | Version Check | Host Setup |
| 07 | 07_phase1_tools | Phase 1 Tools | Phase 1 Tools |
| 08 | 08_phase2_tools | Phase 2 Tools | Phase 2 Tools |
| 09 | 09_chroot_mounts | Mount Chroot | Phase 3 System |
| 10 | 10_phase3_system | System Build | Phase 3 System |
| 11 | 11_kernel | Kernel Build | Kernel & Boot |
| 12 | 12_finalize | Finalize System | Kernel & Boot |
| 13 | 13_teardown | Teardown | Kernel & Boot |

## Selective package builds

From the web dashboard, open a step's package list and run a single package
(`POST /api/step/{idx}/run?pkg=<name>`). Single-package builds bypass the
phase-completion gate, so you can rebuild individual packages (e.g. after a
script fix) without touching the rest.

## Resume after failure

1. Fix the underlying issue.
2. Press **ENTER** on the failed step. Completed packages are skipped via
   markers in `.build_state/` and `/var/lib/ginger/`.
3. To force a full re-run of a step, press **F**.

## Clear a marker

```bash
sudo rm .build_state/<step-id>.built
sudo rm /mnt/ginger_lfs/var/lib/ginger/<package>.built
```

## Snapshots

- **CTRL+S** takes a snapshot of the current image state.
- Restore from the dashboard's snapshot panel or
  `POST /api/snapshots/restore/{snap_name}`.
