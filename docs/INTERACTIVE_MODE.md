# GingerOS Interactive Build Mode - Quick Start Guide

## Overview
The interactive build mode allows you to run GingerOS build steps one at a time, validate markers, and control execution with keyboard commands.

## Usage

### List All Steps
```bash
python3 ginger_os.py --list
# or
python3 ginger_os.py -l
```
Shows all 15 build steps with their current status (✓ Complete or ○ Pending)

### Show Marker Status
```bash
python3 ginger_os.py --markers
# or
python3 ginger_os.py -m
```
Displays which steps have completion markers

### Run a Specific Step
```bash
# Run step 5 (Download Sources)
python3 ginger_os.py --step 5
# or
python3 ginger_os.py -s 5

# Force run even if marker exists
python3 ginger_os.py --step 5 --force
# or
python3 ginger_os.py -s 5 -f
```

### Interactive Mode (Recommended)
```bash
python3 ginger_os.py --interactive
# or
python3 ginger_os.py -i
```

## Interactive Mode Controls

When in interactive mode, you'll see each step with these options:

| Key | Action |
|-----|--------|
| **ENTER** | Run current step (respects markers) |
| **f** | Force run (ignore markers) |
| **s** | Skip current step |
| **j** | Jump to specific step number |
| **l** | List all steps |
| **q** | Quit interactive mode |

## Example Workflow

### 1. Check What's Been Done
```bash
python3 ginger_os.py --markers
```

### 2. Start Interactive Mode
```bash
python3 ginger_os.py --interactive
```

### 3. Navigate Through Steps
- Press **ENTER** to run steps that haven't been completed
- Press **s** to skip steps you don't want to run
- Press **j** then enter a number to jump to a specific step
- Press **f** to force re-run a step that's already complete

### 4. Run Individual Steps
```bash
# Run just the download step
python3 ginger_os.py --step 5

# Run phase 1 toolchain
python3 ginger_os.py --step 9

# Force re-run host setup
python3 ginger_os.py --step 6 --force
```

## Build Steps Reference

| # | Step ID | Name | Phase |
|---|---------|------|-------|
| 1 | 01_fix_repo | Fix Repo Ownership | Preparation |
| 2 | 02_host_reqs | Host Requirements | Preparation |
| 3 | 03_version_check | Version Check | Preparation |
| 4 | 04_prepare_image | Prepare Image | Preparation |
| 5 | 05_download_sources | Download Sources | Preparation |
| 6 | 07_host_setup | Host Setup | Preparation |
| 7 | 08_update_dir | Update Directories | Preparation |
| 8 | 09_setup_lfs_env | Setup LFS Environment | Host Tools |
| 9 | 10_phase1_toolchain | Toolchain Build | Phase 1 Toolchain |
| 10 | 11_phase2_toolchain | Cross Tools Build | Phase 2 Cross Tools |
| 11 | 12_chroot_mounts | Mount Chroot | Phase 3 System |
| 12 | 13_phase3_system | System Build | Phase 3 System |
| 13 | 14_kernel | Kernel Build | Kernel & Boot |
| 14 | 15_grub | Grub Setup | Kernel & Boot |
| 15 | 16_teardown | Teardown | Kernel & Boot |

## Tips

### Validate Before Proceeding
After each step completes, you can:
1. Check the logs in `logs/` directory
2. Verify markers in `/mnt/lfs/var/lib/ginger/`
3. Inspect the build output

### Resume After Failure
If a step fails:
1. Fix the issue
2. Use `--force` to re-run the failed step
3. Or jump to the failed step in interactive mode and press **f**

### Clear Markers
To re-run a step, you can either:
- Use `--force` flag
- Manually delete the marker file:
  ```bash
  sudo rm /mnt/lfs/var/lib/ginger/<step-name>.built
  sudo rm .build_state/<step-id>.built
  ```

## Automated Build (Original Behavior)
To run the full automated build with the fancy UI:
```bash
python3 ginger_os.py
```
This will run all steps automatically, showing the Rich UI with progress bars and live logs.

---

**Pro Tip**: Start with `--list` to see what's been done, then use `--interactive` to step through the remaining work!
