# GingerOS - Command-First Build System

## Launch
```bash
python3 ginger_os.py
```

## Interface

The TUI shows:
- **Header**: Stats (total/complete/pending)
- **Left Panel**: List of all build steps with status
- **Right Panel**: Details of selected step + live output
- **Footer**: Keyboard shortcuts

## How It Works

**YOU** control everything with keyboard commands. Nothing runs automatically.

### Containerized Architecture (Docker-Exec Style)
GingerOS builds itself completely isolated from your host system using a "Zero-Host-Pollution" workflow:
1. **Virtual Disk**: It creates a raw QEMU `.img` file and mounts it natively.
2. **Ubuntu Base**: It uses `debootstrap` to install a minimal Ubuntu 24.04 base directly into the image.
3. **Bind Execution**: The orchestrator bind-mounts the `ginger_os` repository into the image and runs all compilation scripts using `chroot` (acting exactly like `docker exec`).

This means your host machine stays completely clean, and the final output is a portable QEMU disk image.

## Keyboard Commands

### Navigation
- **↑** or **k** - Move up
- **↓** or **j** - Move down  
- **g** or **Home** - Go to first step
- **G** or **End** - Go to last step

### Actions
- **ENTER** - Run selected step (skips if already done)
- **f** - Force run (ignore marker, run anyway)
- **d** - Delete marker (reset step to pending)
- **a** - Run ALL pending steps (auto-continues)
- **s** - Skip to next pending step

### Other
- **?** - Toggle help panel
- **q** or **ESC** - Quit

## Workflow

1. **Launch**: `python3 ginger_os.py`
2. **Navigate**: Use **j/k** or arrow keys to select a step
3. **Execute**: Press **ENTER** to run it
4. **Watch**: See live output in the details panel
5. **Continue**: Navigate to next step and repeat

## Features

✅ **Command-driven** - Nothing runs unless you tell it to
✅ **Visual selection** - See exactly what you're running
✅ **Live output** - Watch logs as step executes
✅ **Smart skipping** - ENTER skips completed steps
✅ **Force mode** - Press **f** to re-run anything
✅ **Batch mode** - Press **a** to run all pending
✅ **Bright colors** - Works great on transparent terminals

## Examples

### Run Steps One-by-One
```
1. Launch TUI
2. Press j to move down
3. Press ENTER to run
4. Wait for completion
5. Press j, ENTER for next
```

### Run All Pending
```
1. Launch TUI
2. Press a
3. Watch it run all pending steps
```

### Re-run a Failed Step
```
1. Navigate to failed step
2. Press d to delete marker
3. Press ENTER to run again
```

### Force Re-run
```
1. Navigate to any step
2. Press f to force run
```

---

**Simple. Command-driven. Full control.**

## Requirements
- Python 3.8+
- `rich` library (`pip install rich`)
- `qemu-utils` (for creating the raw image)
- `debootstrap` (for installing the Ubuntu Base container environment)

## Directory Structure
- `logs/`: Build logs for each step
- `.build_state/`: Internal state markers
- `sources/`: Downloaded tarballs (LFS sources)
- `scripts/`: Build logic (Host, Phase 1-3)
