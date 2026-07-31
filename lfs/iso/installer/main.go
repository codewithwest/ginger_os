package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"

	"golang.org/x/term"
)

const (
	colorReset  = "\033[0m"
	colorGreen  = "\033[32m"
	colorCyan   = "\033[36m"
	colorYellow = "\033[33m"
	colorRed    = "\033[31m"
	colorBold   = "\033[1m"
	colorDim    = "\033[2m"
	colorBlue   = "\033[34m"
	clearScreen = "\033[2J\033[H"
)

const logo = `
  _____ _                         ____   ______
 / ____(_)                       / __ \ / ____|
| |  __ _ _ __   __ _  ___ _ __ | |  | | (___
| | |_ | | '_ \ / _` + "`" + ` |/ _ \ '__|| |  | |\___ \
| |__| | | | | | (_| |  __/ |   | |__| |____) |
 \_____|_|_| |_|\__, |\___|_|    \____/|_____/
                __/ |
               |___/         v2.0 [Go Installer]
`

var stepTitles = []string{
	"Welcome",
	"Partitioning",
	"Extractions",
	"Hardware Sync",
	"User Setup",
	"Bootloader",
}

type installer struct {
	targetDev    string
	username     string
	password     string
	rootPassword string
	step         int
}

func printf(color, format string, args ...any) {
	fmt.Print(color)
	fmt.Printf(format, args...)
	fmt.Print(colorReset)
}

func printfln(color, format string, args ...any) {
	printf(color, format+"\n", args...)
}

func readLine() string {
	r := bufio.NewReader(os.Stdin)
	s, _ := r.ReadString('\n')
	return strings.TrimRight(s, "\r\n")
}

func readPassword() string {
	fd := int(os.Stdin.Fd())
	old, _ := term.GetState(fd)
	term.MakeRaw(fd)
	defer term.Restore(fd, old)
	r := bufio.NewReader(os.Stdin)
	s, _ := r.ReadString('\n')
	fmt.Println()
	return strings.TrimRight(s, "\r\n")
}

func pause() {
	fmt.Print(colorDim + "Press [ENTER] to continue..." + colorReset)
	readLine()
}

func renderSteps(current int) {
	for i, title := range stepTitles {
		prefix := "  ○"
		clr := colorDim
		if i < current {
			prefix = "  " + colorGreen + "✔" + colorReset
			clr = colorGreen
		} else if i == current {
			prefix = " " + colorCyan + "▶" + colorReset
			clr = colorCyan + colorBold
		}
		fmt.Printf("  %s %s%s%s\n", prefix, clr, title, colorReset)
	}
}

func showHeader(title string) {
	fmt.Print(clearScreen)
	printfln(colorCyan+colorBold, "╔══════════════════════════════════════════╗")
	printfln(colorCyan+colorBold, "║        GingerOS Installer v2.0           ║")
	printfln(colorCyan+colorBold, "╚══════════════════════════════════════════╝")
	fmt.Println()
	if title != "" {
		printfln(colorYellow+colorBold, "  ── %s ──", title)
		fmt.Println()
	}
}

func (inst *installer) welcome() {
	showHeader("")
	printfln(colorCyan, logo)
	fmt.Println()
	printfln(colorBold, "  Welcome to the GingerOS Installation Suite.")
	fmt.Println()
	printfln(colorDim, "  This tool will deploy GingerOS LFS Edition")
	printfln(colorDim, "  to your target machine.")
	fmt.Println()
	renderSteps(0)
	fmt.Println()
	pause()
	inst.step = 1
}

func (inst *installer) diskSelection() {
	showHeader("STEP 1: Disk Selection")
	renderSteps(1)
	fmt.Println()

	for {
		cmd := exec.Command("lsblk", "-d", "-n", "-p", "-o", "NAME,SIZE,MODEL")
		out, err := cmd.Output()
		if err != nil {
			printfln(colorRed, "  Failed to list disks: %v", err)
			pause()
			return
		}

		lines := strings.Split(strings.TrimSpace(string(out)), "\n")
		var disks []string
		for _, l := range lines {
			l = strings.TrimSpace(l)
			if l == "" || strings.Contains(l, "sr0") || strings.Contains(l, "loop") {
				continue
			}
			disks = append(disks, l)
		}

		fmt.Println()
		for i, d := range disks {
			printfln(colorBlue, "  [%d]  %s", i+1, d)
		}
		fmt.Println()
		printf(colorYellow+colorBold, "  Enter target disk number or path (e.g. /dev/sda): ")
		input := readLine()

		var dev string
		if input == "" {
			continue
		}
		if strings.HasPrefix(input, "/dev/") {
			dev = input
		} else {
			var idx int
			n, _ := fmt.Sscanf(input, "%d", &idx)
			if n != 1 || idx < 1 || idx > len(disks) {
				printfln(colorRed, "  Invalid selection.")
				pause()
				continue
			}
			parts := strings.Fields(disks[idx-1])
			dev = parts[0]
		}

		if _, err := os.Stat(dev); err != nil {
			printfln(colorRed, "  Device %s not found.", dev)
			pause()
			continue
		}
		inst.targetDev = dev
		fmt.Println()
		printfln(colorGreen, "  Selected: %s", dev)
		break
	}
	inst.step = 2
}

func (inst *installer) userSetup() {
	showHeader("STEP 5: User Setup")
	renderSteps(4)
	fmt.Println()
	printfln(colorDim, "  Define the primary system administrator account.")
	fmt.Println()

	printf(colorYellow+colorBold, "  Username [ginger]: ")
	u := readLine()
	if u == "" {
		u = "ginger"
	}
	inst.username = u

	fmt.Print("\n")
	printf(colorYellow+colorBold, "  Password for %s: ", inst.username)
	inst.password = readPassword()
	fmt.Println()

	fmt.Print("\n")
	printf(colorYellow+colorBold, "  Root password: ")
	inst.rootPassword = readPassword()
	fmt.Println()
	fmt.Println()
	printfln(colorGreen, "  User account configured.")
	inst.step = 5
}

func (inst *installer) confirm() {
	showHeader("DEPLOYMENT CONFIRMATION")
	renderSteps(inst.step)
	fmt.Println()

	printfln(colorRed+colorBold, "  ⚠ WARNING: ALL DATA ON TARGET DISK WILL BE DESTROYED!")
	fmt.Println()
	printfln(colorBold, "  Target disk:  %s%s%s", colorCyan, inst.targetDev, colorReset)
	printfln(colorBold, "  Username:     %s%s%s", colorCyan, inst.username, colorReset)
	fmt.Println()
	printf(colorYellow+colorBold, "  Type 'YES' to begin installation: ")

	ans := strings.ToUpper(strings.TrimSpace(readLine()))
	if ans != "YES" && ans != "Y" {
		printfln(colorRed, "\n  Installation aborted.")
		os.Exit(0)
	}
}

func (inst *installer) runInstall() {
	showHeader("INSTALLATION IN PROGRESS")
	renderSteps(inst.step)
	fmt.Println()

	log := func(format string, args ...any) {
		fmt.Printf("  %s>%s ", colorCyan, colorReset)
		fmt.Printf(format+"\n", args...)
	}

	log("──────────────────────────────────────")
	log("Target: %s", inst.targetDev)
	log("──────────────────────────────────────")
	fmt.Println()

	rootPart := inst.targetDev + "1"
	mnt := "/mnt/ginger"

	run := func(desc, cmd string, args ...string) error {
		log("%s ...", desc)
		c := exec.Command(cmd, args...)
		c.Stdout = os.Stdout
		c.Stderr = os.Stderr
		return c.Run()
	}

	runQuiet := func(desc, cmd string, args ...string) error {
		log("%s ...", desc)
		c := exec.Command(cmd, args...)
		return c.Run()
	}

	step := func(n int, title string, fn func() error) {
		inst.step = n
		printfln(colorYellow, "\n  ── STEP %d/%d: %s ──\n", n, len(stepTitles), title)
		if err := fn(); err != nil {
			printfln(colorRed, "\n  ✖ FAILED at step %d: %v", n, err)
			os.Exit(1)
		}
		printfln(colorGreen, "\n  ✔ Step %d complete.\n", n)
	}

	step(1, "Partitioning", func() error {
		if err := runQuiet("Wiping old signatures", "wipefs", "-a", inst.targetDev); err != nil {
			// non-fatal
		}
		if err := runQuiet("Creating MBR partition table", "parted", "-s", inst.targetDev, "mklabel", "msdos"); err != nil {
			return err
		}
		if err := runQuiet("Creating ext4 partition", "parted", "-s", inst.targetDev, "mkpart", "primary", "ext4", "1MiB", "100%"); err != nil {
			return err
		}
		runQuiet("Probing partitions", "partprobe", inst.targetDev)
		runQuiet("Waiting for devices", "udevadm", "settle")
		if err := runQuiet("Formatting as ext4", "mkfs.ext4", "-F", rootPart); err != nil {
			return err
		}
		runQuiet("Probing partitions", "partprobe", inst.targetDev)
		runQuiet("Waiting for devices", "udevadm", "settle")
		return nil
	})

	step(2, "Extracting rootfs", func() error {
		os.MkdirAll(mnt, 0755)
		if err := runQuiet("Mounting root partition", "mount", rootPart, mnt); err != nil {
			return err
		}
		log("Extracting root filesystem (this may take a while)...")
		return run("Extracting gingeros-base-rootfs.tar.gz", "tar", "-xpf", "/mnt/iso/installer/gingeros-base-rootfs.tar.gz", "-C", mnt)
	})

	step(3, "Hardware sync", func() error {
		os.MkdirAll(filepath.Join(mnt, "boot"), 0755)
		if err := run("Installing kernel", "cp", "/mnt/iso/boot/vmlinuz", filepath.Join(mnt, "boot/vmlinuz-ginger")); err != nil {
			return err
		}
		runQuiet("Waiting for devices", "udevadm", "settle")

		log("Detecting partition UUID...")
		uuidOut, err := exec.Command("blkid", "-s", "UUID", "-o", "value", rootPart).Output()
		if err != nil || len(uuidOut) == 0 {
			uuidOut, err = exec.Command("lsblk", "-no", "UUID", rootPart).Output()
		}
		rootUUID := strings.TrimSpace(string(uuidOut))
		if rootUUID == "" {
			return fmt.Errorf("failed to detect UUID for %s", rootPart)
		}
		log("Root UUID: %s", rootUUID)

		log("Creating absolute merged-/usr symlinks...")
		type link struct{ target, link string }
		for _, l := range []link{
			{"/usr/bin", "bin"}, {"/usr/sbin", "sbin"}, {"/usr/lib", "lib"},
		} {
			os.RemoveAll(filepath.Join(mnt, l.link))
			os.Symlink(l.target, filepath.Join(mnt, l.link))
		}
		if _, err := os.Stat(filepath.Join(mnt, "usr/lib64")); err == nil {
			os.RemoveAll(filepath.Join(mnt, "lib64"))
			os.Symlink("/usr/lib64", filepath.Join(mnt, "lib64"))
		} else {
			os.RemoveAll(filepath.Join(mnt, "lib64"))
			os.Symlink("/usr/lib", filepath.Join(mnt, "lib64"))
		}
		return nil
	})

	step(4, "User setup", func() error {
		for _, d := range []string{"dev", "proc", "sys"} {
			os.MkdirAll(filepath.Join(mnt, d), 0755)
		}
		syscall.Mount("/dev", filepath.Join(mnt, "dev"), "", syscall.MS_BIND, "")
		syscall.Mount("/proc", filepath.Join(mnt, "proc"), "proc", 0, "")
		syscall.Mount("/sys", filepath.Join(mnt, "sys"), "sysfs", 0, "")

		chrootCmd := fmt.Sprintf(
			`useradd -m -s /bin/bash '%s' 2>/dev/null || true
echo 'root:%s' | chpasswd
echo '%s:%s' | chpasswd
grep -q '^sudo:' /etc/group && usermod -aG sudo '%s' || true`,
			inst.username, inst.rootPassword, inst.username, inst.password, inst.username)
		cmd := exec.Command("chroot", mnt, "/bin/bash", "-c", chrootCmd)
		if out, err := cmd.CombinedOutput(); err != nil {
			log("Warning: user creation issues (non-fatal): %s", string(out))
		} else {
			log("User '%s' created.", inst.username)
		}

		syscall.Unmount(filepath.Join(mnt, "sys"), 0)
		syscall.Unmount(filepath.Join(mnt, "proc"), 0)
		syscall.Unmount(filepath.Join(mnt, "dev"), 0)
		return nil
	})

	step(5, "Bootloader", func() error {
		log("Setting hostname...")
		os.WriteFile(filepath.Join(mnt, "etc/hostname"), []byte("gingeros\n"), 0644)

		log("Writing /etc/hosts...")
		hosts := `# Begin /etc/hosts
127.0.0.1   localhost.localdomain localhost
127.0.1.1   gingeros.example.org gingeros
::1         localhost.localdomain localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
# End /etc/hosts
`
		os.WriteFile(filepath.Join(mnt, "etc/hosts"), []byte(hosts), 0644)

		log("Configuring network...")
		networkDir := filepath.Join(mnt, "etc/systemd/network")
		os.MkdirAll(networkDir, 0755)
		network := `[Match]
Name=en* eth* ens* eno* wlp* wlan*

[Network]
DHCP=ipv4
`
		os.WriteFile(filepath.Join(networkDir, "20-dhcp.network"), []byte(network), 0644)

		resolv := `# Begin /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
# End /etc/resolv.conf
`
		os.WriteFile(filepath.Join(mnt, "etc/resolv.conf"), []byte(resolv), 0644)

		log("Sanitizing library environment...")
		ldconf := `/lib
/usr/lib
/usr/local/lib
`
		os.WriteFile(filepath.Join(mnt, "etc/ld.so.conf"), []byte(ldconf), 0644)
		os.RemoveAll(filepath.Join(mnt, "lib/x86_64-linux-gnu"))
		os.RemoveAll(filepath.Join(mnt, "usr/lib/x86_64-linux-gnu"))

		log("Creating net-test tool...")
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
		os.WriteFile(filepath.Join(mnt, "usr/bin/net-test"), []byte(netTest), 0755)

		log("Running ldconfig...")
		exec.Command("chroot", mnt, "ldconfig").Run()

		log("Installing GRUB...")
		for _, d := range []string{"dev", "proc", "sys"} {
			os.MkdirAll(filepath.Join(mnt, d), 0755)
		}
		syscall.Mount("/dev", filepath.Join(mnt, "dev"), "", syscall.MS_BIND, "")
		syscall.Mount("/proc", filepath.Join(mnt, "proc"), "proc", 0, "")
		syscall.Mount("/sys", filepath.Join(mnt, "sys"), "sysfs", 0, "")
		if err := runQuiet("Installing GRUB to "+inst.targetDev, "grub-install", "--target=i386-pc", "--boot-directory="+filepath.Join(mnt, "boot"), inst.targetDev); err != nil {
			return err
		}
		syscall.Unmount(filepath.Join(mnt, "sys"), 0)
		syscall.Unmount(filepath.Join(mnt, "proc"), 0)
		syscall.Unmount(filepath.Join(mnt, "dev"), 0)

		log("Writing GRUB config...")
		os.MkdirAll(filepath.Join(mnt, "boot/grub"), 0755)
		grubCfg := `set default=0
set timeout=5

menuentry 'GingerOS' {
    linux /boot/vmlinuz-ginger root=/dev/sda1 rw rootwait systemd.show_status=1 net.ifnames=0
}
`
		os.WriteFile(filepath.Join(mnt, "boot/grub/grub.cfg"), []byte(grubCfg), 0644)

		log("Writing GingerOS branding...")
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
		os.WriteFile(filepath.Join(mnt, "etc/issue"), []byte(issue), 0644)

		syscall.Sync()
		return nil
	})

	inst.step = len(stepTitles)
}

func main() {
	inst := &installer{
		username: "ginger",
	}

	if len(os.Args) > 1 && os.Args[1] == "--install" {
		// Non-interactive mode for debugging
		inst.targetDev = "/dev/sda"
		inst.password = "ginger"
		inst.rootPassword = "root"
		inst.runInstall()
		return
	}

	inst.welcome()
	inst.diskSelection()
	inst.userSetup()
	inst.confirm()
	inst.runInstall()

	fmt.Print(clearScreen)
	printfln(colorGreen+colorBold, "\n  ✔ DEPLOYMENT COMPLETE")
	fmt.Println()
	printfln(colorDim, "  GingerOS is now installed on %s.", inst.targetDev)
	printfln(colorDim, "  Remove installation media and reboot.")
	fmt.Println()
	pause()
}
