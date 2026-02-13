# GingerOS Build System - Quick Start

## Launch
```bash
python3 ginger_os.py
```

## What Happens

The build system starts **paused** and shows:
- 🌶️ Your GingerOS logo
- Build roadmap (all steps)
- Keyboard controls
- Welcome message: "Press SPACE or ENTER to start the build..."

## Keyboard Controls

### Start/Control Build
- **SPACE** or **ENTER** - Start build (when paused) or Resume (when paused)
- **N** - Skip to next step
- **S** - Skip current step  
- **L** - List all steps in logs
- **?** - Show help
- **Q** - Quit

### On Error
- **R** - Restart phase
- **P** - Restart package
- **Ctrl+C** - Abort

## Workflow

1. **Launch**: `python3 ginger_os.py`
2. **Review**: Look at the roadmap, see what steps exist
3. **Start**: Press **SPACE** or **ENTER** to begin
4. **Control**: Use keyboard shortcuts as needed
5. **Monitor**: Watch live logs and progress

## Features

✅ Starts paused - you control when it runs
✅ Your logo and Rich UI preserved
✅ Live progress bars and logs
✅ Keyboard shortcuts always available
✅ Smart step skipping
✅ Error recovery

## CLI Options (Still Available)

```bash
# List steps without starting UI
python3 ginger_os.py --list

# Run specific step only
python3 ginger_os.py --step 5

# Force run (ignore markers)
python3 ginger_os.py --step 5 --force

# Show markers
python3 ginger_os.py --markers
```

---

**That's it! One command, full control.**
