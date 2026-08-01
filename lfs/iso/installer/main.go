package main

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
	"unicode/utf8"

	"golang.org/x/term"
)

// serialConsole mirrors the debug log to /dev/ttyS0 so the serial capture
// keeps command-level diagnostics even though /dev/console is the VGA tty0.
// stderr is also redirected to the serial console so Go panics land there.
var serialConsole *os.File

func initSerialMirror() {
	f, err := os.OpenFile("/dev/ttyS0", os.O_WRONLY, 0)
	if err != nil {
		return
	}
	serialConsole = f
	os.Stderr = f
}

const (
	colorReset  = "\033[0m"
	colorBold   = "\033[1m"
	colorDim    = "\033[2m"
	colorGreen  = "\033[32m"
	colorCyan   = "\033[36m"
	colorYellow = "\033[33m"
	colorRed    = "\033[31m"
	clearScreen = "\033[H\033[J"
)

const logo = `██████╗ ██╗███╗   ██╗ ██████╗ ███████╗██████╗  ██████╗ ███████╗
██╔════╝ ██║████╗  ██║██╔════╝ ██╔════╝██╔══██╗██╔═══██╗██╔════╝
██║  ███╗██║██╔██╗ ██║██║  ███╗█████╗  ██████╔╝██║   ██║███████╗
██║   ██║██║██║╚██╗██║██║   ██║██╔══╝  ██╔══██╗██║   ██║╚════██║
╚██████╔╝██║██║ ╚████║╚██████╔╝███████╗██║  ██║╚██████╔╝███████║
 ╚═════╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝`

var stepTitles = []string{
	"Welcome",
	"Partitioning",
	"Extract Filesystem",
	"Hardware Sync",
	"User Setup",
	"Bootloader",
}

var spinnerFrames = []string{"┤", "┘", "┴", "└", "├", "┌", "┬", "┐"}

type installer struct {
	targetDev    string
	username     string
	password     string
	rootPassword string
	step         int
}

type debugLogger struct {
	mu        sync.Mutex
	ramPath   string
	diskPath  string
	diskReady bool
	serial    bool
}

var dl = &debugLogger{
	ramPath:  "/tmp/ginger-install.log",
	diskPath: "/mnt/ginger/var/log/ginger-install.log",
	serial:   true,
}

func (l *debugLogger) append(path, line string) {
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return
	}
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0644)
	if err != nil {
		return
	}
	defer f.Close()
	f.WriteString(line + "\n")
	if path == l.diskPath {
		f.Sync()
	}
}

func (l *debugLogger) logf(format string, args ...any) {
	l.mu.Lock()
	defer l.mu.Unlock()
	line := time.Now().Format("2006-01-02 15:04:05") + "  " + fmt.Sprintf(format, args...)
	l.append(l.ramPath, line)
	if l.diskReady {
		l.append(l.diskPath, line)
	}
	if serialConsole != nil && l.serial {
		fmt.Fprintf(serialConsole, "DBG %s\n", line)
	}
}

func printf(color, format string, args ...any) {
	fmt.Print(color)
	fmt.Printf(format, args...)
	fmt.Print(colorReset)
}

func printfln(color, format string, args ...any) {
	printf(color, format+"\n", args...)
}

func stripANSI(s string) string {
	var b strings.Builder
	inEsc := false
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == 0x1b {
			inEsc = true
			continue
		}
		if inEsc {
			if c == 'm' {
				inEsc = false
			}
			continue
		}
		b.WriteByte(c)
	}
	return b.String()
}

func rlen(s string) int { return utf8.RuneCountInString(stripANSI(s)) }

func padTo(s string, n int) string {
	if rlen(s) >= n {
		return s
	}
	return s + strings.Repeat(" ", n-rlen(s))
}

func frame(title string, content []string) {
	inner := 44
	for _, l := range content {
		if n := rlen(l); n > inner {
			inner = n
		}
	}
	w := inner + 6

	fmt.Print(colorCyan + colorBold)
	if title != "" {
		t := "─ " + title + " ─"
		pad := w - 4 - rlen(t)
		left := pad / 2
		right := pad - left
		fmt.Printf("  ╭%s%s%s╮\n", strings.Repeat("─", left), t, strings.Repeat("─", right))
	} else {
		fmt.Printf("  ╭%s╮\n", strings.Repeat("─", w-4))
	}
	fmt.Print(colorReset)

	for _, l := range content {
		fmt.Printf("  ║ %s ║\n", padTo(l, inner))
	}

	fmt.Print(colorCyan + colorBold)
	fmt.Printf("  ╰%s╯\n", strings.Repeat("─", w-4))
	fmt.Print(colorReset)
}

func elapsed(start time.Time) string {
	d := time.Since(start)
	if d < time.Second {
		return ""
	}
	return d.Round(time.Second).String()
}

func humanSize(b int64) string {
	units := []string{"B", "KiB", "MiB", "GiB", "TiB"}
	f := float64(b)
	u := 0
	for f >= 1024 && u < len(units)-1 {
		f /= 1024
		u++
	}
	if u == 0 {
		return fmt.Sprintf("%d B", b)
	}
	return fmt.Sprintf("%.1f %s", f, units[u])
}

func progressBar(pct float64, w int) string {
	fill := int(pct * float64(w) / 100)
	if fill < 0 {
		fill = 0
	}
	if fill > w {
		fill = w
	}
	return colorGreen + strings.Repeat("█", fill) + colorDim + strings.Repeat("░", w-fill) + colorReset
}

func gzipUncompressedSize(path string) int64 {
	out, err := exec.Command("gzip", "-l", path).Output()
	if err != nil {
		return 0
	}
	for _, ln := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		f := strings.Fields(ln)
		if len(f) >= 2 && f[0] != "compressed" && f[0] != "total" {
			if n, err := strconv.ParseInt(f[1], 10, 64); err == nil {
				return n
			}
		}
	}
	return 0
}

func dirSize(dir string) int64 {
	out, err := exec.Command("du", "-sb", dir).Output()
	if err != nil {
		return 0
	}
	f := strings.Fields(string(out))
	if len(f) == 0 {
		return 0
	}
	n, _ := strconv.ParseInt(f[0], 10, 64)
	return n
}

func readLine() string {
	r := bufio.NewReader(os.Stdin)
	s, _ := r.ReadString('\n')
	return strings.TrimRight(s, "\r\n")
}

func readPassword() string {
	fd := int(os.Stdin.Fd())
	pw, _ := term.ReadPassword(fd)
	fmt.Println()
	return strings.TrimRight(string(pw), "\r\n")
}

func writeFileSync(path string, data []byte, perm os.FileMode) error {
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, perm)
	if err != nil {
		return err
	}
	defer f.Close()
	if _, err := f.Write(data); err != nil {
		return err
	}
	return f.Sync()
}

func pause() {
	fmt.Print(colorDim + "Press [ENTER] to continue..." + colorReset)
	readLine()
}

func (inst *installer) welcome() {
	fmt.Print(clearScreen)
	logoLines := strings.Split(logo, "\n")
	colored := []string{""}
	for _, l := range logoLines {
		colored = append(colored, "  "+colorCyan+colorBold+l+colorReset)
	}
	colored = append(colored, "")
	frame("GingerOS Installer", colored)
	fmt.Println()
	printfln(colorDim, "     GingerOS — Linux From Scratch 13.0 · systemd")
	fmt.Println()
	frame("Deployment Steps", []string{
		"  " + colorDim + "○  1. Partitioning" + colorReset,
		"  " + colorDim + "○  2. Extract root filesystem" + colorReset,
		"  " + colorDim + "○  3. Hardware sync" + colorReset,
		"  " + colorDim + "○  4. User setup" + colorReset,
		"  " + colorDim + "○  5. Bootloader" + colorReset,
	})
	fmt.Println()
	pause()
	inst.step = 1
}

func (inst *installer) diskSelection() {
	fmt.Print(clearScreen)
	frame("STEP 1 · Disk Selection", []string{
		"  " + colorDim + "Select the disk where GingerOS will be installed." + colorReset,
		"  " + colorDim + "WARNING: all existing data on it will be erased." + colorReset,
	})
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

		content := []string{"  " + colorCyan + colorBold + "Available disks" + colorReset, ""}
		for i, d := range disks {
			content = append(content, fmt.Sprintf("  %s[%d]%s  %s", colorYellow+colorBold, i+1, colorReset, d))
		}
		content = append(content, "")
		frame("", content)
		fmt.Println()

		printf(colorYellow+colorBold, "  Enter disk number or path (e.g. /dev/sda): ")
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
		dl.logf("Target disk selected: %s", dev)
		printfln(colorGreen, "\n  Selected: %s", dev)
		pause()
		break
	}
	inst.step = 2
}

func (inst *installer) userSetup() {
	fmt.Print(clearScreen)
	frame("STEP 4 · User Setup", []string{
		"  " + colorDim + "Define the primary system administrator account." + colorReset,
	})
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

	fmt.Print("\n")
	printf(colorYellow+colorBold, "  Root password: ")
	inst.rootPassword = readPassword()

	fmt.Println()
	printfln(colorGreen, "  User account configured.")
	pause()
	inst.step = 5
}

func (inst *installer) confirm() {
	fmt.Print(clearScreen)
	frame("Deployment Confirmation", []string{
		"  " + colorRed + colorBold + "⚠  ALL DATA ON THE TARGET DISK WILL BE DESTROYED  ⚠" + colorReset,
		"",
		"  " + colorBold + "Target disk:  " + colorCyan + inst.targetDev + colorReset,
		"  " + colorBold + "Username:     " + colorCyan + inst.username + colorReset,
		"  " + colorBold + "Bootloader:   " + colorCyan + "GRUB (MBR)" + colorReset,
	})
	fmt.Println()
	printf(colorYellow+colorBold, "  Type 'YES' to begin installation: ")

	ans := strings.ToUpper(strings.TrimSpace(readLine()))
	if ans != "YES" && ans != "Y" {
		printfln(colorRed, "\n  Installation aborted.")
		os.Exit(0)
	}
	inst.step = 2
}

func (inst *installer) runInstall() {
	steps := []string{"Partitioning", "Extract Filesystem", "Hardware Sync", "User Setup", "Bootloader"}
	rootPart := inst.targetDev + "1"
	mnt := "/mnt/ginger"

	render := func(current int, status string) {
		fmt.Print(clearScreen)
		printfln(colorCyan+colorBold, "  ╔══════════════════════════════════════════════════╗")
		printfln(colorCyan+colorBold, "  ║      GingerOS Installer v2.0 — Deploying          ║")
		printfln(colorCyan+colorBold, "  ╚══════════════════════════════════════════════════╝")
		fmt.Println()
		lines := []string{}
		for i, s := range steps {
			num := strconv.Itoa(i + 1)
			switch {
			case i < current:
				lines = append(lines, "  "+colorGreen+"✔"+colorReset+"   "+colorDim+"Step "+num+colorReset+"   "+s)
			case i == current:
				lines = append(lines, "  "+colorCyan+"▶"+colorReset+"   "+colorYellow+colorBold+"Step "+num+colorReset+"   "+colorYellow+colorBold+s+colorReset)
			default:
				lines = append(lines, "  "+colorDim+"○"+colorReset+"   "+colorDim+"Step "+num+colorReset+"   "+colorDim+s+colorReset)
			}
		}
		frame("Deployment Steps", lines)
		fmt.Println()
		fmt.Println("  " + status)
		fmt.Println()
	}

	flushed := false
	flush := func() {
		if flushed {
			return
		}
		flushed = true
		dl.logf("FLUSH: syncing filesystem")
		fmt.Println("  [flush] Syncing filesystem...")
		syscall.Sync()
		syscall.Sync()
		for _, mp := range []string{"sys", "proc", "dev"} {
			syscall.Unmount(filepath.Join(mnt, mp), 0)
		}
		syscall.Unmount(mnt, 0)
		dl.logf("FLUSH: unmounted and synced")
		fmt.Println("  [flush] Unmounted and synced.")
	}

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM, syscall.SIGQUIT)
	go func() {
		sig := <-sigCh
		dl.logf("SIGNAL %v received, flushing data before exit", sig)
		fmt.Printf("\n\n  Received signal %v. Flushing data before exit...\n", sig)
		flush()
		fmt.Println("  Installer interrupted. Target disk may be incomplete.")
		os.Exit(130)
	}()

	execRun := func(update func(string), desc, cmd string, args ...string) error {
		update(desc)
		dl.logf("cmd: %s %s", cmd, strings.Join(args, " "))
		c := exec.Command(cmd, args...)
		var buf bytes.Buffer
		c.Stdout = &buf
		c.Stderr = &buf
		if err := c.Run(); err != nil {
			msg := strings.TrimSpace(buf.String())
			if msg != "" {
				dl.logf("FAIL %s: %v (%s)", desc, err, msg)
				return fmt.Errorf("%s: %v (%s)", desc, err, msg)
			}
			dl.logf("FAIL %s: %v", desc, err)
			return fmt.Errorf("%s: %v", desc, err)
		}
		dl.logf("OK   %s", desc)
		return nil
	}

	step := func(n int, title string, fn func(update func(string)) error) error {
		inst.step = n
		dl.logf("STEP %d START: %s", n, title)
		i := 0
		start := time.Now()
		done := make(chan error, 1)
		statusCh := make(chan string, 8)
		go func() {
			done <- fn(func(s string) {
				select {
				case statusCh <- s:
				default:
				}
			})
		}()
		cur := title
		for {
			select {
			case err := <-done:
				if err != nil {
					dl.logf("STEP %d FAILED: %s: %v", n, title, err)
					render(n, "  "+colorRed+colorBold+"✖  "+title+" failed:"+colorReset+" "+err.Error())
					return err
				}
				dl.logf("STEP %d OK: %s (%s)", n, title, elapsed(start))
				render(n, "  "+colorGreen+colorBold+"✔  "+title+" complete  "+colorReset+colorDim+elapsed(start)+colorReset)
				time.Sleep(600 * time.Millisecond)
				return nil
			case s := <-statusCh:
				cur = s
			case <-time.After(250 * time.Millisecond):
				i++
				sp := spinnerFrames[i%len(spinnerFrames)]
				render(n, "  "+colorCyan+sp+colorReset+"  "+colorYellow+cur+colorReset+"  "+colorDim+elapsed(start)+colorReset)
			}
		}
	}

	if err := step(1, "Partitioning", func(update func(string)) error {
		update("Wiping old signatures...")
		dl.logf("cmd: wipefs -a %s", inst.targetDev)
		exec.Command("wipefs", "-a", inst.targetDev).Run()
		if err := execRun(update, "Creating MBR partition table", "parted", "-s", inst.targetDev, "mklabel", "msdos"); err != nil {
			return err
		}
		if err := execRun(update, "Creating ext4 partition", "parted", "-s", inst.targetDev, "mkpart", "primary", "ext4", "1MiB", "100%"); err != nil {
			return err
		}
		dl.logf("cmd: partprobe %s", inst.targetDev)
		exec.Command("partprobe", inst.targetDev).Run()
		dl.logf("cmd: udevadm settle")
		exec.Command("udevadm", "settle").Run()
		if err := execRun(update, "Formatting as ext4", "mkfs.ext4", "-F", rootPart); err != nil {
			return err
		}
		dl.logf("cmd: partprobe %s", inst.targetDev)
		exec.Command("partprobe", inst.targetDev).Run()
		dl.logf("cmd: udevadm settle")
		exec.Command("udevadm", "settle").Run()
		return nil
	}); err != nil {
		os.Exit(1)
	}

	if err := step(2, "Extract Filesystem", func(update func(string)) error {
		if err := os.MkdirAll(mnt, 0755); err != nil {
			return err
		}
		update("Mounting root partition...")
		if err := execRun(update, "Mounting root partition", "mount", rootPart, mnt); err != nil {
			return err
		}
		dl.diskReady = true
		dl.logf("Debug logging enabled on target: %s", dl.diskPath)

		total := gzipUncompressedSize("/mnt/iso/installer/gingeros-base-rootfs.tar.gz")
		dl.logf("extract: uncompressed size %d", total)
		tarDone := make(chan error, 1)
		go func() {
			c := exec.Command("tar", "-xpf", "/mnt/iso/installer/gingeros-base-rootfs.tar.gz", "-C", mnt)
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
				sz := dirSize(mnt)
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
	}); err != nil {
		os.Exit(1)
	}

	if err := step(3, "Hardware Sync", func(update func(string)) error {
		if err := os.MkdirAll(filepath.Join(mnt, "boot"), 0755); err != nil {
			return err
		}
		if err := execRun(update, "Installing kernel", "cp", "/mnt/iso/boot/vmlinuz", filepath.Join(mnt, "boot/vmlinuz-ginger")); err != nil {
			return err
		}
		dl.logf("cmd: udevadm settle")
		exec.Command("udevadm", "settle").Run()

		update("Detecting partition UUID...")
		uuidOut, err := exec.Command("blkid", "-s", "UUID", "-o", "value", rootPart).Output()
		if err != nil || len(uuidOut) == 0 {
			uuidOut, err = exec.Command("lsblk", "-no", "UUID", rootPart).Output()
		}
		rootUUID := strings.TrimSpace(string(uuidOut))
		dl.logf("root partition UUID: %q", rootUUID)
		if rootUUID == "" {
			return fmt.Errorf("failed to detect UUID for %s", rootPart)
		}

		// The shipped rootfs fstab still carries the build disk's root UUID.
		// Rewrite the root entry with the freshly-formatted target's UUID, or
		// systemd-remount-fs.service fails at first boot.
		update("Updating /etc/fstab root UUID...")
		fstabPath := filepath.Join(mnt, "etc/fstab")
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
			os.RemoveAll(filepath.Join(mnt, l.link))
			os.Symlink(l.target, filepath.Join(mnt, l.link))
		}
		if _, err := os.Stat(filepath.Join(mnt, "usr/lib64")); err == nil {
			os.RemoveAll(filepath.Join(mnt, "lib64"))
			os.Symlink("usr/lib64", filepath.Join(mnt, "lib64"))
		} else {
			os.RemoveAll(filepath.Join(mnt, "lib64"))
			os.Symlink("usr/lib", filepath.Join(mnt, "lib64"))
		}
		return nil
	}); err != nil {
		os.Exit(1)
	}

	if err := step(4, "User Setup", func(update func(string)) error {
		for _, d := range []string{"dev", "proc", "sys"} {
			if err := os.MkdirAll(filepath.Join(mnt, d), 0755); err != nil {
				return err
			}
		}
		update("Mounting virtual filesystems...")
		syscall.Mount("/dev", filepath.Join(mnt, "dev"), "", syscall.MS_BIND, "")
		syscall.Mount("/proc", filepath.Join(mnt, "proc"), "proc", 0, "")
		syscall.Mount("/sys", filepath.Join(mnt, "sys"), "sysfs", 0, "")

		update("Creating user account...")
		chrootCmd := fmt.Sprintf(
			`useradd -m -s /bin/bash '%s' 2>/dev/null || true
echo 'root:%s' | chpasswd
echo '%s:%s' | chpasswd
grep -q '^sudo:' /etc/group && usermod -aG sudo '%s' || true`,
			inst.username, inst.rootPassword, inst.username, inst.password, inst.username)
		cmd := exec.Command("chroot", mnt, "/bin/bash", "-c", chrootCmd)
		if _, err := cmd.CombinedOutput(); err != nil {
			update("Warning: user creation issues (non-fatal)")
		} else {
			update("User '" + inst.username + "' created.")
		}

		syscall.Unmount(filepath.Join(mnt, "sys"), 0)
		syscall.Unmount(filepath.Join(mnt, "proc"), 0)
		syscall.Unmount(filepath.Join(mnt, "dev"), 0)
		return nil
	}); err != nil {
		os.Exit(1)
	}

	if err := step(5, "Bootloader", func(update func(string)) error {
		update("Writing system configuration...")
		if err := writeFileSync(filepath.Join(mnt, "etc/hostname"), []byte("gingeros\n"), 0644); err != nil {
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
		if err := writeFileSync(filepath.Join(mnt, "etc/hosts"), []byte(hosts), 0644); err != nil {
			return err
		}

		networkDir := filepath.Join(mnt, "etc/systemd/network")
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
		if err := writeFileSync(filepath.Join(mnt, "etc/resolv.conf"), []byte(resolv), 0644); err != nil {
			return err
		}

		ldconf := `/lib
/usr/lib
/usr/local/lib
`
		if err := writeFileSync(filepath.Join(mnt, "etc/ld.so.conf"), []byte(ldconf), 0644); err != nil {
			return err
		}
		os.RemoveAll(filepath.Join(mnt, "lib/x86_64-linux-gnu"))
		os.RemoveAll(filepath.Join(mnt, "usr/lib/x86_64-linux-gnu"))

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
		if err := writeFileSync(filepath.Join(mnt, "usr/bin/net-test"), []byte(netTest), 0755); err != nil {
			return err
		}

		update("Running ldconfig...")
		dl.logf("cmd: chroot %s ldconfig", mnt)
		exec.Command("chroot", mnt, "ldconfig").Run()

		for _, d := range []string{"dev", "proc", "sys"} {
			if err := os.MkdirAll(filepath.Join(mnt, d), 0755); err != nil {
				return err
			}
		}
		syscall.Mount("/dev", filepath.Join(mnt, "dev"), "", syscall.MS_BIND, "")
		syscall.Mount("/proc", filepath.Join(mnt, "proc"), "proc", 0, "")
		syscall.Mount("/sys", filepath.Join(mnt, "sys"), "sysfs", 0, "")

		update("Installing GRUB to " + inst.targetDev + "...")
		grubCmd := "PATH=/usr/sbin:/usr/bin:/sbin:/bin grub-install --target=i386-pc --boot-directory=/boot " + inst.targetDev
		dl.logf("cmd: chroot %s %s", mnt, grubCmd)
		out, err := exec.Command("chroot", mnt, "/bin/bash", "-c", grubCmd).CombinedOutput()
		if err != nil {
			if msg := strings.TrimSpace(string(out)); msg != "" {
				dl.logf("FAIL Installing GRUB: %v (%s)", err, msg)
				return fmt.Errorf("Installing GRUB: %v (%s)", err, msg)
			}
			dl.logf("FAIL Installing GRUB: %v", err)
			return fmt.Errorf("Installing GRUB: %v", err)
		}
		dl.logf("OK   Installing GRUB")
		syscall.Unmount(filepath.Join(mnt, "sys"), 0)
		syscall.Unmount(filepath.Join(mnt, "proc"), 0)
		syscall.Unmount(filepath.Join(mnt, "dev"), 0)

		if err := os.MkdirAll(filepath.Join(mnt, "boot/grub"), 0755); err != nil {
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
		if err := writeFileSync(filepath.Join(mnt, "boot/grub/grub.cfg"), []byte(grubCfg), 0644); err != nil {
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
		if err := writeFileSync(filepath.Join(mnt, "etc/issue"), []byte(issue), 0644); err != nil {
			return err
		}

		update("Finalizing...")
		dl.logf("=== INSTALLATION COMPLETE ===")
		if err := os.Remove(dl.diskPath); err == nil {
			dl.logf("removed %s (install complete)", dl.diskPath)
		}
		flush()
		return nil
	}); err != nil {
		os.Exit(1)
	}

	flush()
	inst.step = len(stepTitles)
}

func main() {
	initSerialMirror()

	inst := &installer{
		username: "ginger",
	}

	dl.logf("=== GingerOS Installer starting ===")
	if b, err := os.ReadFile("/proc/version"); err == nil {
		dl.logf("kernel: %s", strings.TrimSpace(string(b)))
	}
	for _, e := range []string{"PWD", "PATH"} {
		if v, ok := os.LookupEnv(e); ok {
			dl.logf("env %s=%s", e, v)
		}
	}

	if len(os.Args) > 1 && os.Args[1] == "--install" {
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
	frame("✔ DEPLOYMENT COMPLETE", []string{
		"",
		"  " + colorGreen + colorBold + "GingerOS is now installed on " + inst.targetDev + colorReset,
		"",
		"  " + colorDim + "Remove the installation media and reboot." + colorReset,
		"",
	})
	fmt.Println()
	pause()
}
