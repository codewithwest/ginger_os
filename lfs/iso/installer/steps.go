package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

// stepPartition wipes the target disk and creates a single ext4 partition.
func (d *deployer) stepPartition(update func(string)) error {
	update("Wiping old signatures...")
	dl.logf("cmd: wipefs -a %s", d.targetDev)
	exec.Command("wipefs", "-a", d.targetDev).Run()
	if err := d.execRun(update, "Creating MBR partition table", "parted", "-s", d.targetDev, "mklabel", "msdos"); err != nil {
		return err
	}
	if err := d.execRun(update, "Creating ext4 partition", "parted", "-s", d.targetDev, "mkpart", "primary", "ext4", "1MiB", "100%"); err != nil {
		return err
	}
	dl.logf("cmd: partprobe %s", d.targetDev)
	exec.Command("partprobe", d.targetDev).Run()
	dl.logf("cmd: udevadm settle")
	exec.Command("udevadm", "settle").Run()
	if err := d.execRun(update, "Formatting as ext4", "mkfs.ext4", "-F", d.rootPart); err != nil {
		return err
	}
	dl.logf("cmd: partprobe %s", d.targetDev)
	exec.Command("partprobe", d.targetDev).Run()
	dl.logf("cmd: udevadm settle")
	exec.Command("udevadm", "settle").Run()
	return nil
}

// stepExtract mounts the target and extracts the base rootfs with progress.
func (d *deployer) stepExtract(update func(string)) error {
	if err := os.MkdirAll(d.mnt, 0755); err != nil {
		return err
	}
	update("Mounting root partition...")
	if err := d.execRun(update, "Mounting root partition", "mount", d.rootPart, d.mnt); err != nil {
		return err
	}
	dl.diskReady = true
	dl.logf("Debug logging enabled on target: %s", dl.diskPath)

	total := gzipUncompressedSize("/mnt/iso/installer/gingeros-base-rootfs.tar.gz")
	dl.logf("extract: uncompressed size %d", total)
	tarDone := make(chan error, 1)
	go func() {
		c := exec.Command("tar", "-xpf", "/mnt/iso/installer/gingeros-base-rootfs.tar.gz", "-C", d.mnt)
		var buf bytes.Buffer
		c.Stdout = &buf
		c.Stderr = &buf
		tarDone <- c.Run()
	}()
	defer func() {
		select {
		case err := <-tarDone:
			if err != nil {
				dl.logf("tar exit: %v", err)
			} else {
				dl.logf("tar OK")
			}
		default:
		}
	}()

	for {
		select {
		case err := <-tarDone:
			syscall.Sync()
			if err != nil {
				dl.logf("tar FAILED: %v", err)
				return err
			}
			dl.logf("tar completed successfully")
			return nil
		case <-time.After(time.Second):
			sz := dirSize(d.mnt)
			if total > 0 {
				pct := float64(sz) / float64(total) * 100
				if pct > 100 {
					pct = 100
				}
				update(fmt.Sprintf("Extracting rootfs  %s  %5.1f%%  (%s / %s)",
					progressBar(pct, 22), pct, humanSize(sz), humanSize(total)))
			} else {
				update(fmt.Sprintf("Extracting rootfs  %s extracted", humanSize(sz)))
			}
		}
	}
}

// stepHardware syncs kernel, fstab UUID, and merged-/usr symlinks.
func (d *deployer) stepHardware(update func(string)) error {
	if err := os.MkdirAll(filepath.Join(d.mnt, "boot"), 0755); err != nil {
		return err
	}
	if err := d.execRun(update, "Installing kernel", "cp", "/mnt/iso/boot/vmlinuz", filepath.Join(d.mnt, "boot/vmlinuz-ginger")); err != nil {
		return err
	}
	dl.logf("cmd: udevadm settle")
	exec.Command("udevadm", "settle").Run()

	update("Detecting partition UUID...")
	uuidOut, err := exec.Command("blkid", "-s", "UUID", "-o", "value", d.rootPart).Output()
	if err != nil || len(uuidOut) == 0 {
		uuidOut, err = exec.Command("lsblk", "-no", "UUID", d.rootPart).Output()
	}
	rootUUID := strings.TrimSpace(string(uuidOut))
	dl.logf("root partition UUID: %q", rootUUID)
	if rootUUID == "" {
		return fmt.Errorf("failed to detect UUID for %s", d.rootPart)
	}

	// The shipped rootfs fstab still carries the build disk's root UUID.
	// Rewrite the root entry with the freshly-formatted target's UUID, or
	// systemd-remount-fs.service fails at first boot.
	update("Updating /etc/fstab root UUID...")
	fstabPath := filepath.Join(d.mnt, "etc/fstab")
	fstabData, err := os.ReadFile(fstabPath)
	if err != nil {
		return fmt.Errorf("failed to read %s: %w", fstabPath, err)
	}
	fstabLines := strings.Split(string(fstabData), "\n")
	for i, line := range fstabLines {
		fields := strings.Fields(line)
		if len(fields) >= 3 && fields[1] == "/" {
			fstabLines[i] = "UUID=" + rootUUID + line[len(fields[0]):]
			break
		}
	}
	if err := writeFileSync(fstabPath, []byte(strings.Join(fstabLines, "\n")), 0644); err != nil {
		return err
	}

	// Use RELATIVE symlink targets so any later traversal (chroot, os.RemoveAll,
	// ldconfig) resolves them inside the target and never escapes into the live
	// initrd root. Absolute targets like "/usr/lib" point at the live root.
	update("Creating merged-/usr symlinks...")
	type link struct{ target, link string }
	for _, l := range []link{
		{"usr/bin", "bin"}, {"usr/sbin", "sbin"}, {"usr/lib", "lib"},
	} {
		os.RemoveAll(filepath.Join(d.mnt, l.link))
		os.Symlink(l.target, filepath.Join(d.mnt, l.link))
	}
	if _, err := os.Stat(filepath.Join(d.mnt, "usr/lib64")); err == nil {
		os.RemoveAll(filepath.Join(d.mnt, "lib64"))
		os.Symlink("usr/lib64", filepath.Join(d.mnt, "lib64"))
	} else {
		os.RemoveAll(filepath.Join(d.mnt, "lib64"))
		os.Symlink("usr/lib", filepath.Join(d.mnt, "lib64"))
	}
	return nil
}

// stepUsers creates the primary user account and sets passwords.
func (d *deployer) stepUsers(update func(string)) error {
	for _, dir := range []string{"dev", "proc", "sys"} {
		if err := os.MkdirAll(filepath.Join(d.mnt, dir), 0755); err != nil {
			return err
		}
	}
	update("Mounting virtual filesystems...")
	syscall.Mount("/dev", filepath.Join(d.mnt, "dev"), "", syscall.MS_BIND, "")
	syscall.Mount("/proc", filepath.Join(d.mnt, "proc"), "proc", 0, "")
	syscall.Mount("/sys", filepath.Join(d.mnt, "sys"), "sysfs", 0, "")

	update("Creating user account...")
	chrootCmd := fmt.Sprintf(
		`useradd -m -s /bin/bash '%s' 2>/dev/null || true
echo 'root:%s' | chpasswd
echo '%s:%s' | chpasswd
grep -q '^sudo:' /etc/group && usermod -aG sudo '%s' || true`,
		d.inst.username, d.inst.rootPassword, d.inst.username, d.inst.password, d.inst.username)
	cmd := exec.Command("chroot", d.mnt, "/bin/bash", "-c", chrootCmd)
	if _, err := cmd.CombinedOutput(); err != nil {
		update("Warning: user creation issues (non-fatal)")
	} else {
		update("User '" + d.inst.username + "' created.")
	}

	syscall.Unmount(filepath.Join(d.mnt, "sys"), 0)
	syscall.Unmount(filepath.Join(d.mnt, "proc"), 0)
	syscall.Unmount(filepath.Join(d.mnt, "dev"), 0)
	return nil
}

// stepBootloader writes system config and installs GRUB.
func (d *deployer) stepBootloader(update func(string)) error {
	update("Writing system configuration...")
	if err := writeFileSync(filepath.Join(d.mnt, "etc/hostname"), []byte("gingeros\n"), 0644); err != nil {
		return err
	}

	hosts := `# Begin /etc/hosts
127.0.0.1   localhost.localdomain localhost
127.0.1.1   gingeros.example.org gingeros
::1         localhost.localdomain localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
# End /etc/hosts
`
	if err := writeFileSync(filepath.Join(d.mnt, "etc/hosts"), []byte(hosts), 0644); err != nil {
		return err
	}

	networkDir := filepath.Join(d.mnt, "etc/systemd/network")
	if err := os.MkdirAll(networkDir, 0755); err != nil {
		return err
	}
	network := `[Match]
Name=en* eth* ens* eno* wlp* wlan*

[Network]
DHCP=ipv4
`
	if err := writeFileSync(filepath.Join(networkDir, "20-dhcp.network"), []byte(network), 0644); err != nil {
		return err
	}

	resolv := `# Begin /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
# End /etc/resolv.conf
`
	if err := writeFileSync(filepath.Join(d.mnt, "etc/resolv.conf"), []byte(resolv), 0644); err != nil {
		return err
	}

	ldconf := `/lib
/usr/lib
/usr/local/lib
`
	if err := writeFileSync(filepath.Join(d.mnt, "etc/ld.so.conf"), []byte(ldconf), 0644); err != nil {
		return err
	}
	os.RemoveAll(filepath.Join(d.mnt, "lib/x86_64-linux-gnu"))
	os.RemoveAll(filepath.Join(d.mnt, "usr/lib/x86_64-linux-gnu"))

	netTest := `#!/bin/bash
echo "--- GingerOS Network Health Check ---"
echo "1. Checking Loopback..."
ip addr show lo | grep -q "UP" && echo "[OK] Loopback is UP" || echo "[FAIL] Loopback is DOWN"
echo "2. Checking Gateway..."
ip route | grep -q "default" && echo "[OK] Default route exists" || echo "[FAIL] No default route"
echo "3. Testing Raw DNS Connection..."
(echo > /dev/udp/8.8.8.8/53) >/dev/null 2>&1 && echo "[OK] Can reach Google DNS" || echo "[FAIL] Internet unreachable"
echo "4. Testing HTTP Handshake..."
(echo > /dev/tcp/google.com/80) >/dev/null 2>&1 && echo "[OK] Web handshake successful" || echo "[FAIL] Web unreachable"
`
	if err := writeFileSync(filepath.Join(d.mnt, "usr/bin/net-test"), []byte(netTest), 0755); err != nil {
		return err
	}

	update("Running ldconfig...")
	dl.logf("cmd: chroot %s ldconfig", d.mnt)
	exec.Command("chroot", d.mnt, "ldconfig").Run()

	for _, dir := range []string{"dev", "proc", "sys"} {
		if err := os.MkdirAll(filepath.Join(d.mnt, dir), 0755); err != nil {
			return err
		}
	}
	syscall.Mount("/dev", filepath.Join(d.mnt, "dev"), "", syscall.MS_BIND, "")
	syscall.Mount("/proc", filepath.Join(d.mnt, "proc"), "proc", 0, "")
	syscall.Mount("/sys", filepath.Join(d.mnt, "sys"), "sysfs", 0, "")

	update("Installing GRUB to " + d.targetDev + "...")
	grubCmd := "PATH=/usr/sbin:/usr/bin:/sbin:/bin grub-install --target=i386-pc --boot-directory=/boot " + d.targetDev
	dl.logf("cmd: chroot %s %s", d.mnt, grubCmd)
	out, err := exec.Command("chroot", d.mnt, "/bin/bash", "-c", grubCmd).CombinedOutput()
	if err != nil {
		if msg := strings.TrimSpace(string(out)); msg != "" {
			dl.logf("FAIL Installing GRUB: %v (%s)", err, msg)
			return fmt.Errorf("Installing GRUB: %v (%s)", err, msg)
		}
		dl.logf("FAIL Installing GRUB: %v", err)
		return fmt.Errorf("Installing GRUB: %v", err)
	}
	dl.logf("OK   Installing GRUB")
	syscall.Unmount(filepath.Join(d.mnt, "sys"), 0)
	syscall.Unmount(filepath.Join(d.mnt, "proc"), 0)
	syscall.Unmount(filepath.Join(d.mnt, "dev"), 0)

	if err := os.MkdirAll(filepath.Join(d.mnt, "boot/grub"), 0755); err != nil {
		return err
	}
	grubCfg := `set default=0
set timeout=5

serial --unit=0 --speed=115200
terminal_input console serial
terminal_output console serial

menuentry 'GingerOS' {
    linux /boot/vmlinuz-ginger root=/dev/sda1 rw rootwait console=tty0 console=ttyS0 loglevel=6 systemd.show_status=1 net.ifnames=0
}
`
	if err := writeFileSync(filepath.Join(d.mnt, "boot/grub/grub.cfg"), []byte(grubCfg), 0644); err != nil {
		return err
	}

	issue := `

   ____ _                         ____  ____
  / ___(_)_ __   __ _  ___ _ __  / __ \/ ___|
 | |  _| | '_ \ / _` + "`" + ` |/ _ \ '__|| |  | \___ \
 | |_| | | | | | (_| |  __/ |   | |__| |___) |
  \____|_|_| |_|\__, |\___|_|    \____/|____/
                 |___/

 GingerOS LFS Edition - \l
Kernel \r on an \m

`
	if err := writeFileSync(filepath.Join(d.mnt, "etc/issue"), []byte(issue), 0644); err != nil {
		return err
	}

	update("Finalizing...")
	dl.logf("=== INSTALLATION COMPLETE ===")
	if err := os.Remove(dl.diskPath); err == nil {
		dl.logf("removed %s (install complete)", dl.diskPath)
	}
	d.flush()
	return nil
}
