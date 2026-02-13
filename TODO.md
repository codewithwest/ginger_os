# GingerOS TODO List
## From Audit Report - 2026-02-13

---

## 🔴 CRITICAL (Must Fix Before Merge)

- [x] **Issue #5**: Fix race condition in `scripts/lib/ui.sh` ui_monitor startup (Line 300-304)
  - Replace `pgrep` check with atomic PID file creation
  - File: `scripts/lib/ui.sh`

- [x] **Issue #2**: Add safety checks to `scripts/lib/common.sh` wildcard removal (Line 145)
  - Prevent accidental deletion if DIR_NAME is empty/malformed
  - File: `scripts/lib/common.sh`

- [x] **Issue #4**: Fix error handler to call cleanup (Line 202-206)
  - Ensure build directories are cleaned up on error
  - File: `scripts/lib/common.sh`

- [x] **Build Failsafes**: Automated Mount & Chroot Recovery
  - Automatically re-mounts /mnt/lfs if lost during build
  - Automatically restores chroot virtual filesystems if missing for phase 3/4
  - Files: `lfs_builder_ui/engine.py`, `scripts/image/prepare-image.sh`

- [x] **Deprecated Test Operator**: Replace `-a` with `&&` in phase scripts
  - Files: `scripts/phases/build-phase1.sh`, `build-phase2.sh`

- [x] **Chroot Verification**: Add mount verification before Phase 3
  - Add `_verify_chroot_ready()` method to engine.py
  - File: `lfs_builder_ui/engine.py`

---

## 🟠 HIGH PRIORITY (Should Fix)

- [x] **Testing**: Add basic test suite
  - [x] Unit tests for Python engine (skip logic, phase completion)
  - [x] Integration tests for bash scripts (extract, cleanup)
  - [x] Shellcheck integration

- [x] **Issue #8**: Fix terminal resource conflict in keyboard listener
  - Use `select()` with timeout instead of blocking read
  - File: `lfs_builder_ui/engine.py` (Lines 75-99)
  - *Note: Superseded by new TUI architecture in ginger_os.py*

- [x] **Issue #11**: Add subprocess timeout mechanism
  - Prevent hangs on stuck build steps
  - File: `lfs_builder_ui/engine.py` (Lines 316-326)

- [x] **Documentation**: Update README.md
  - Document new directory structure
  - Add Python requirements (Rich library)
  - Update build instructions

- [x] **Issue #12**: Add input validation to `run-as-lfs.sh`
  - Validate script path before execution
  - File: `scripts/host/run-as-lfs.sh`

---

## 🟡 MEDIUM PRIORITY (Nice to Have)

- [x] **Issue #6**: Replace `source` with safe parsing in `ui_load_state`
  - Prevent arbitrary code execution from corrupted state files
  - File: `scripts/lib/ui.sh` (Line 102)

- [x] **CI/CD**: Add shellcheck to pipeline
  - Run on all `.sh` files
  - Fix all warnings/errors

- [x] **Documentation**: Add docstrings to Python engine methods
  - File: `lfs_builder_ui/engine.py`

- [x] **Issue #9**: Make `GINGER_PKG:` marker more unique
  - Change to `__GINGER_PKG_MARKER__:` to avoid false positives
  - Files: `scripts/phases/*.sh`, `lfs_builder_ui/engine.py`

- [x] **Issue #10**: Fix storage update timing logic
  - Replace probabilistic timing with explicit counter
  - File: `lfs_builder_ui/engine.py` (Line 338)

---

## 🟢 LOW PRIORITY (Future Enhancements)

- [x] Add configuration file support (avoid hardcoded paths)
- [x] Implement build telemetry (time per package, failure rates)
- [x] Add `--dry-run` mode to preview build plan
- [ ] Support parallel package builds where dependencies allow
- [ ] Add web-based UI option for remote builds

---

## 🔧 REFACTORING

- [ ] **Marker System**: Revert to master's simpler marker approach
  - Remove dual marker system (host + LFS)
  - Use single source of truth
  - Simplify skip logic in phase orchestrators

- [x] **Interactive Mode**: Add step-by-step build execution
  - [x] Allow running individual phases/packages
  - [x] Pause between steps for validation
  - [x] Manual marker management

---

## 📝 NOTES

### Issue Reference Guide
- **Issue #1**: Unsafe variable expansion in common.sh (Line 113) - Already quoted
- **Issue #2**: Dangerous wildcard removal (Line 145) - CRITICAL
- **Issue #3**: Path normalization edge case (Line 149) - Minor
- **Issue #4**: Error handler doesn't cleanup (Line 202-206) - CRITICAL
- **Issue #5**: Race condition in UI monitor (Line 300-304) - CRITICAL
- **Issue #6**: Unsafe state file sourcing (Line 102) - MEDIUM
- **Issue #8**: Terminal resource conflict (Lines 75-99) - HIGH
- **Issue #9**: Subprocess output parsing fragility (Lines 327-356) - MEDIUM
- **Issue #10**: Storage update timing (Line 338) - MEDIUM
- **Issue #11**: No subprocess timeout (Lines 316-326) - HIGH
- **Issue #12**: Unvalidated script execution (Line 15) - HIGH
- **Issue #13**: Sudo without password timeout - MEDIUM
- **Issue #14**: Unvalidated GINGER_ROOT - MEDIUM
- **Issue #15**: Shell=True in subprocess - DOCUMENTED (currently safe)
- **Issue #16**: Unbounded log accumulation - ACCEPTABLE (50MB rotation)

---

**Last Updated**: 2026-02-13  
**Source**: audit_report.md
