---
description: How to build GingerOS
---

This workflow details the process to build GingerOS from source.

## Prerequisites
- A Linux host (Ubuntu recommended).
- Sudo privileges.
- At least 30GB of free space.

## Build Steps

The build process is automated by `ginger_os.sh`.

1.  Navigate to the project directory:
    ```bash
    cd /home/jonas/Documents/west/ginger_os
    ```

2.  Run the automated build script:
    // turbo
    ```bash
    sudo ./ginger_os.sh
    ```

3.  Monitor the logs. The script will output INFO logs to the terminal.
    - If the script fails, check the error message.
    - Fix the issue.
    - Re-run `sudo ./ginger_os.sh`. It will skip already completed steps.

4.  Once finished, the disk image `ginger_os.img` will be ready.

## Cleanup

The script automatically tears down the chroot and mounts at the end. If you need to manually clean up:
```bash
sudo ./teardown.sh
```
