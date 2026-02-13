# GingerOS TUI - K9s-Style Interface

## Quick Start

```bash
# Launch the TUI
python3 ginger_tui.py
```

## Interface Overview

```
┌─────────────────────────────────────────────────────────┐
│  🌶️  GingerOS Build System  🌶️     Total: 15  ✓: 4  ○: 11 │
├─────────────────────────────────────────────────────────┤
│  #  │ Status   │ Step Name           │ Phase            │
│─────┼──────────┼─────────────────────┼──────────────────│
│  1  │ Pending  │ Fix Repo Ownership  │ Preparation      │
│▶ 2  │ Pending  │ Host Requirements   │ Preparation      │ ← Selected
│  3  │ Pending  │ Version Check       │ Preparation      │
│  4  │ Complete │ Prepare Image       │ Preparation      │
│  5  │ Pending  │ Download Sources    │ Preparation      │
│ ... │          │                     │                  │
├─────────────────────────────────────────────────────────┤
│ ↑↓/jk=nav  ENTER=run  f=force  d=delete  ?=help  q=quit │
└─────────────────────────────────────────────────────────┘
```

## Keyboard Shortcuts

### Navigation
- **↑** or **k** - Move selection up
- **↓** or **j** - Move selection down

### Actions
- **ENTER** - Run selected step (respects markers)
- **f** - Force run selected step (ignore markers)
- **d** - Delete marker for selected step

### Filters
- **a** - Show all steps
- **p** - Show pending steps only
- **c** - Show completed steps only

### Other
- **r** - Refresh display
- **?** - Toggle help panel
- **q** or **ESC** - Quit

## Features

### Visual Step Selection
- Navigate through steps with arrow keys or vim-style j/k
- Selected step is highlighted with cyan background
- See status at a glance (✓ Complete / ○ Pending)

### Smart Filtering
- **All** (default) - Show all 15 steps
- **Pending** - Show only steps without markers
- **Complete** - Show only steps with markers

### Marker Management
- Run steps with ENTER (auto-skips if marker exists)
- Force re-run with **f** key
- Delete markers with **d** key to reset a step

### Real-time Status
- Header shows total/complete/pending counts
- Status updates after running steps
- Filter indicator in footer

## Workflow Examples

### 1. Review Build Status
```
1. Launch TUI: python3 ginger_tui.py
2. Press 'p' to see only pending steps
3. Press 'c' to see what's been completed
4. Press 'a' to see everything again
```

### 2. Run Steps One-by-One
```
1. Launch TUI
2. Use ↓ or j to navigate to desired step
3. Press ENTER to run
4. After completion, press ENTER to return to TUI
5. Repeat for next step
```

### 3. Re-run a Failed Step
```
1. Navigate to the failed step
2. Press 'd' to delete its marker
3. Press ENTER to run it again
```

### 4. Force Re-run Without Deleting Marker
```
1. Navigate to the step
2. Press 'f' to force run
3. Marker will be recreated on success
```

## Comparison with CLI Mode

| Feature | TUI Mode | CLI Mode |
|---------|----------|----------|
| Visual navigation | ✓ Full-screen UI | ✗ Text prompts |
| Step filtering | ✓ a/p/c keys | ✗ Manual |
| Status overview | ✓ Always visible | ✗ Need --list |
| Marker management | ✓ d key | ✗ Manual rm |
| Keyboard shortcuts | ✓ vim-style | ✗ Limited |
| Help display | ✓ ? key toggle | ✗ --help only |

## Tips

### Vim Users
The TUI uses vim-style navigation:
- **j/k** for down/up (just like vim)
- **ESC** to quit (like :q in vim)

### Quick Workflow
1. Press **p** to see what needs to be done
2. Press **j** to move to first pending step
3. Press **ENTER** to run it
4. Repeat until all done

### Troubleshooting
If a step fails:
1. Check the log file shown in the error message
2. Fix the issue
3. Press **d** to delete the marker
4. Press **ENTER** to re-run

## Advanced Usage

### Filter + Navigate
```
Press 'p'     → Show only pending steps
Press 'j' x3  → Move down 3 steps
Press ENTER   → Run that step
```

### Bulk Marker Cleanup
To reset multiple steps:
```
1. Press 'c' to show completed steps
2. Navigate to each one
3. Press 'd' to delete marker
4. Repeat
```

### Quick Status Check
```
Launch TUI → See header stats → Press 'q' to quit
```

---

**Pro Tip**: Keep the TUI open in one terminal while monitoring logs in another!
