# GingerOS Deployment Operations Guide

GingerOS provides two high-fidelity interfaces for managing your LFS build: the **TUI Console** (for local ops) and the **Neural Command Matrix** (for high-density telemetry).

## Launching the Engine

Execute the primary orchestrator from the root directory:
```bash
python3 ginger_os.py
```
Upon launch, the Web Dashboard will automatically initialize at `http://localhost:8000`.

## Interface Controls

### 1. Neural Command Matrix (Web UI)
The dashboard provides a "Glassmorphism" control center for the build:
- **Auto Protocol**: Toggle this to allow the engine to automatically transition between build steps.
- **Kill Module**: Instantly aborts all active build processes using **Process Group Isolation**.
- **Core Allocation**: Use the slider in the telemetry panel to dynamically set the number of CPU cores used for compilation (`make -jN`).
- **Neural Stream**: A live, high-performance log view of all system output.
- **Temporal Diagnostics**: Live-updating clocks for **Package**, **Phase**, and **Total** build duration.
- **Rebuild UI**: Trigger a fresh production build of the dashboard itself.

### 2. TUI Console (Terminal)
Standard keyboard shortcuts remain active:
- **SPACE / ENTER**: Start or Resume the build.
- **A**: Toggle Auto-mode.
- **S**: Skip current step.
- **F**: Force-run the selected step (ignores markers).
- **Q**: Clean shutdown of all processes and exit.

## Workflow & Optimization

1. **Initialization**: Review the **Deployment Pipeline** list to see which steps are completed (green) or pending.
2. **Resource Tuning**: Adjust the **Core Allocation** slider based on your host system's current load (monitored in the header).
3. **Execution**: Trigger the build via the "Auto Protocol" toggle or by selecting a specific step from the pipeline list.
4. **Monitoring**: Track progress through the **Deployment Sync** meter and the **LFS Mount Capacity** telemetry.
5. **Completion**: Once the pipeline is 100% synchronized, run `./qemu-run.sh` to boot into your new OS.

## System Recovery

If a step fails:
1. Review the **Neural Stream** for the exact error (look for red "SYSTEM_ERROR" markers).
2. The engine will pause automatically.
3. Fix the underlying issue (e.g., download a missing source).
4. Press **ENTER** or toggle **Auto Protocol** to resume from the exact failure point.
