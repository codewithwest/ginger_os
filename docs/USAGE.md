# GingerOS Unified Build Interface

## Overview
The GingerOS build system now features a **unified interface** that combines:
- 🎨 Your beautiful logo and Rich UI
- ⚡ Live build progress and logs
- ⌨️ K9s-style keyboard controls
- 🚀 Automated execution

## Launch the Build

```bash
python3 ginger_os.py
```

That's it! One command, one interface.

## What You'll See

```
┌─────────────────────────────────────────────────────────────┐
│                    🌶️ GingerOS ASCII Logo 🌶️                 │
│              🌶️ GingerOS Build System                       │
│              LFS 12.4 Automata - Cyberpunk Edition          │
├──────────────────┬──────────────────────────────────────────┤
│ ROADMAP          │ SYSTEM STATUS                            │
│ ─── Phase 1 ───  │ OVERALL: ████████░░░░ 65%  ⏱ 12:34     │
│  [✓] Binutils    │ PHASE  : Building GCC  ⏱ 03:21          │
│  [▶] GCC         │ PACKAGE: gcc-13.2.0    ⏱ 01:15          │
│  [ ] Glibc       │ STORAGE: Host ████░░░░ 45%  LFS ███░░ 30%│
│                  ├──────────────────────────────────────────┤
│                  │ LIVE LOGS                                │
│                  │ [12:34:56] Configuring GCC...            │
│                  │ [12:35:01] Building target libraries...  │
│                  │ [12:35:12] Installing to /tools...       │
├──────────────────┴──────────────────────────────────────────┤
│ ⚡ CONTROLS: SPACE=Pause N=Next S=Skip J=Jump L=List ?=Help Q=Quit │
└─────────────────────────────────────────────────────────────┘
```

## Keyboard Controls

### During Build
| Key | Action | Description |
|-----|--------|-------------|
| **SPACE** | Pause/Resume | Pause the build, press again to resume |
| **N** | Next Step | Skip to the next build step |
| **S** | Skip Current | Mark current step complete and move on |
| **J** | Jump | Jump to a specific step number |
| **L** | List Steps | Show all steps with status in logs |
| **?** | Help | Display keyboard shortcuts in logs |
| **Q** | Quit | Abort the build |

### On Error (Paused)
| Key | Action | Description |
|-----|--------|-------------|
| **R** | Restart Phase | Restart the entire current phase |
| **P** | Restart Package | Restart just the failed package |
| **Ctrl+C** | Abort | Exit the build |

## Features

### 1. Automated Execution
- Runs all steps automatically
- Smart skipping of completed steps
- Continues until done or error

### 2. Live Monitoring
- Real-time progress bars
- Live log streaming
- Storage monitoring
- Package-level timing

### 3. Interactive Control
- Pause anytime with SPACE
- Skip steps you don't need
- Jump to specific steps
- List all steps on demand

### 4. Error Recovery
- Auto-pauses on errors
- Restart at phase or package level
- Shows error context in logs

## Workflow Examples

### Normal Build
```bash
python3 ginger_os.py
# Sit back and watch, or press ? to see controls
```

### Pause to Inspect
```bash
# During build:
# 1. Press SPACE to pause
# 2. Check logs, inspect system
# 3. Press SPACE again to resume
```

### Skip Unwanted Steps
```bash
# During build:
# 1. Press L to see all steps
# 2. Press S to skip current step
# 3. Or press N to move to next
```

### Jump to Specific Step
```bash
# During build:
# 1. Press J to jump
# 2. Follow prompt to enter step number
```

### Handle Errors
```bash
# When build pauses on error:
# 1. Read the error in logs
# 2. Press R to restart phase
# 3. Or press P to restart just the package
```

## CLI Mode (Still Available)

You can still use CLI flags for specific tasks:

```bash
# List steps
python3 ginger_os.py --list

# Run specific step
python3 ginger_os.py --step 5

# Interactive prompts
python3 ginger_os.py --interactive
```

## Tips

1. **Press ? anytime** to see keyboard shortcuts
2. **Press L** to see what's pending vs complete
3. **Use SPACE** to pause and inspect before continuing
4. **Press S** to skip steps you've already done manually
5. **Watch the footer** for available controls

## What Changed?

### Before (Separate Modes)
- `ginger_os.py` - Automated only
- `ginger_tui.py` - Interactive only
- Had to choose one or the other

### Now (Unified)
- `python3 ginger_os.py` - Everything in one!
- Logo + Live UI + Keyboard controls
- Best of both worlds

---

**Your logo is preserved, your UI is intact, and now you have full keyboard control!** 🎉
