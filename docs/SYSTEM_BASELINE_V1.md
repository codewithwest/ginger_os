# Ginger OS System Baseline v1

## Goal and constraints

- Preserve the existing Linux From Scratch 13.0 systemd base.
- Extend incrementally; do not rebase to a newer LFS release as part of this baseline.
- Target a practical low-resource laptop, including systems with 2 CPU cores and 16 GiB RAM.
- Keep the installed OS independent of the Ginger AI runtime and graphical UI. The machine must boot, log in, log, and recover when AI services are absent.
- Reuse LFS/BLFS instructions and existing systemd facilities instead of introducing duplicate init, networking, logging, device, or IPC systems.
- Validate the installable ISO and installed system in QEMU before relying on physical-hardware testing. QEMU tests validate repeatability and virtual hardware paths; they do not prove real Wi-Fi, suspend/resume, audio, GPU, or laptop firmware support.

## Baseline service ownership

| Capability | Baseline owner | Policy |
| --- | --- | --- |
| Init and service lifecycle | systemd | Single service manager; avoid duplicate supervisors. |
| Device discovery | systemd/udev | Verify rules and required device nodes. |
| Wired virtual networking | systemd-networkd | DHCP and DNS must be tested from a fresh install. |
| DNS | systemd-resolved, if enabled | Configure the resolver symlink and upstream DNS coherently; avoid hard-coded public DNS as the only path. |
| System logs | journald | Prefer one primary logging path; only add a separate syslog daemon for a demonstrated compatibility need. |
| Sessions and power/session tracking | systemd-logind | Verify login and shutdown/reboot behavior. |
| Local IPC | D-Bus | Retain where required by installed services. |
| Bootloader | GRUB | Verify root UUID, filesystem, and recovery path in the installed image. |
| Accounts and privileges | Existing LFS account tools plus reviewed privilege tooling | No default/empty passwords; no broad agent root access. |
| AI and Ginger apps | Optional higher-level services | Must not be required for boot, login, network, or recovery. |

## Change policy

1. Inventory the actual LFS build scripts, generated root filesystem, and ISO contents before adding packages.
2. Use BLFS as a package and dependency reference, not as a list to install wholesale.
3. For every addition, record the capability gap, dependencies, enablement policy, expected resource cost, test, and rollback.
4. Prefer packages already in the build and systemd features already available.
5. Do not claim a capability is supported merely because a package or kernel option is present; test the resulting behavior.
6. Keep changes small and reviewable. A cleanup, validation, or configuration failure must stop ISO release rather than silently ship an unverified root filesystem.

## QEMU-first validation

Run these checks in a disposable QEMU/KVM virtual machine before calling the baseline validated:

1. Build the LFS image using the documented build workflow.
2. Produce an ISO from a clean build and again using the cached-rootfs path.
3. Verify rootfs archive validation rejects missing essential files and that purge failures stop ISO creation.
4. Install to a new virtual disk using the ISO.
5. Boot the installed disk and verify login, correct root filesystem UUID, expected systemd state, and no emergency shell.
6. Verify the virtual NIC receives DHCP, DNS resolution works, and networking survives a reboot.
7. Verify user setup, password authentication, poweroff, and reboot behavior.
8. Record boot result, service status, memory at idle, CPU idle behavior, and test logs as build artifacts.

QEMU does not validate physical Wi-Fi authentication, suspend/resume, laptop hotkeys, audio, GPU acceleration, or firmware compatibility. Those remain a later hardware qualification stage.

## Acceptance criteria

- ISO generation fails on purge or rootfs validation errors.
- Essential rootfs files are present after purge.
- Fresh and cached ISO builds use a validated rootfs and matching kernel artifact.
- A fresh QEMU installation boots and reaches a login prompt.
- Network DHCP and DNS work in the VM before and after reboot.
- No default credentials or unintended host distribution services are shipped.
- Baseline idle resource usage is measured rather than assumed.
- AI/UI failures do not prevent boot, login, networking, or recovery.

## Known audit items

- Review lfs/phase3-system/90-network.sh alongside 84-systemd.sh for consistent resolver configuration.
- Review lfs/phase3-system/83-sysklogd.sh versus journald to decide whether a second logging daemon is needed.
- Review lfs/phase3-system/77-udev.sh against systemd's installed udev implementation before changing it.
- Make rootfs purge validation and ISO failure behavior strict.
- Review account/privilege setup and the installer as one first-boot security path.
- Tune build parallelism for available memory as well as CPU count; distinguish build-host resources from installed-system runtime usage.
