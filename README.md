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
