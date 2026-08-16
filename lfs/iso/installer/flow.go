package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func (inst *installer) welcome() {
	fmt.Print(clearScreen)
	logoLines := strings.Split(logo, "\n")
	colored := []string{}
	for _, l := range logoLines {
		colored = append(colored, "  "+colorCyan+colorBold+l+colorReset)
	}
	colored = append(colored, "")
	colored = append(colored, "  "+colorDim+"GingerOS — Linux From Scratch 13.0 · systemd"+colorReset)
	colored = append(colored, "  "+colorDim+"Installer v"+installerVersion+colorReset)
	colored = append(colored, "")
	frame("Welcome", colored)
	fmt.Println()

	choice := selectMenu("", []string{
		"Install GingerOS",
		"System information",
		"Reboot",
	})
	switch choice {
	case 1:
		inst.systemInfo()
	case 2:
		exec.Command("reboot").Run()
		os.Exit(0)
	case -1:
		os.Exit(0)
	default:
		inst.step = 1
	}
}

func (inst *installer) systemInfo() {
	fmt.Print(clearScreen)
	content := []string{}
	add := func(label, val string) {
		content = append(content, "  "+colorDim+label+": "+colorReset+colorBold+val+colorReset)
	}
	if b, err := os.ReadFile("/proc/version"); err == nil {
		f := strings.Fields(string(b))
		if len(f) >= 3 {
			add("Kernel", f[0]+" "+f[2])
		}
	}
	if b, err := os.ReadFile("/proc/meminfo"); err == nil {
		for _, l := range strings.Split(string(b), "\n") {
			if strings.HasPrefix(l, "MemTotal") {
				f := strings.Fields(l)
				if len(f) >= 2 {
					add("Memory", f[1]+" "+f[2])
				}
				break
			}
		}
	}
	if b, err := os.ReadFile("/proc/cpuinfo"); err == nil {
		for _, l := range strings.Split(string(b), "\n") {
			if strings.HasPrefix(l, "model name") {
				f := strings.SplitN(l, ":", 2)
				if len(f) == 2 {
					add("CPU", strings.TrimSpace(f[1]))
				}
				break
			}
		}
	}
	frame("System Information", content)
	fmt.Println()
	pause()
}

func (inst *installer) diskSelection() {
	for {
		fmt.Print(clearScreen)
		cmd := exec.Command("lsblk", "-d", "-n", "-p", "-o", "NAME,SIZE,MODEL")
		out, err := cmd.Output()
		if err != nil {
			printfln(colorRed, "  Failed to list disks: %v", err)
			pause()
			return
		}

		var disks []string
		for _, l := range strings.Split(strings.TrimSpace(string(out)), "\n") {
			l = strings.TrimSpace(l)
			if l == "" || strings.Contains(l, "sr0") || strings.Contains(l, "loop") {
				continue
			}
			disks = append(disks, l)
		}
		if len(disks) == 0 {
			printfln(colorRed, "  No disks found.")
			pause()
			return
		}

		frame("STEP 1 · Disk Selection", []string{
			"  " + colorRed + colorBold + "⚠  ALL DATA ON THE SELECTED DISK WILL BE ERASED  ⚠" + colorReset,
			"",
		})
		fmt.Println()
		choice := selectMenu("Available disks", disks)
		if choice < 0 {
			return
		}
		parts := strings.Fields(disks[choice])
		dev := parts[0]

		if _, err := os.Stat(dev); err != nil {
			printfln(colorRed, "  Device %s not found.", dev)
			pause()
			continue
		}
		inst.targetDev = dev
		dl.logf("Target disk selected: %s", dev)

		fmt.Print(clearScreen)
		detail := []string{
			"",
			"  " + colorBold + "Target disk:  " + colorCyan + dev + colorReset,
			"",
		}
		if confirmPrompt("Confirm target disk", detail) {
			break
		}
	}
	inst.step = 2
}

func (inst *installer) userSetup() {
	fmt.Print(clearScreen)
	frame("STEP 4 · User Setup", []string{
		"  " + colorDim + "Define the primary system administrator account." + colorReset,
		"",
	})
	fmt.Println()

	printf(colorYellow+colorBold, "  Username [ginger]: ")
	u := readLine()
	if u == "" {
		u = "ginger"
	}
	inst.username = u

	for {
		fmt.Print("\n")
		printf(colorYellow+colorBold, "  Password for %s: ", inst.username)
		p1 := readPassword()
		fmt.Print("\n")
		printf(colorYellow+colorBold, "  Confirm password: ")
		p2 := readPassword()
		if p1 == p2 && p1 != "" {
			inst.password = p1
			break
		}
		printfln(colorRed, "\n  Passwords do not match.")
	}

	for {
		fmt.Print("\n")
		printf(colorYellow+colorBold, "  Root password: ")
		p1 := readPassword()
		fmt.Print("\n")
		printf(colorYellow+colorBold, "  Confirm root password: ")
		p2 := readPassword()
		if p1 == p2 && p1 != "" {
			inst.rootPassword = p1
			break
		}
		printfln(colorRed, "\n  Root passwords do not match.")
	}

	fmt.Println()
	printfln(colorGreen, "  User account configured.")
	pause()
	inst.step = 5
}

func (inst *installer) confirm() {
	fmt.Print(clearScreen)
	detail := []string{
		"",
		"  " + colorRed + colorBold + "⚠  ALL DATA ON THE TARGET DISK WILL BE DESTROYED  ⚠" + colorReset,
		"",
		"  " + colorBold + "Target disk:  " + colorCyan + inst.targetDev + colorReset,
		"  " + colorBold + "Username:     " + colorCyan + inst.username + colorReset,
		"  " + colorBold + "Bootloader:   " + colorCyan + "GRUB (MBR)" + colorReset,
		"",
	}
	if !confirmPrompt("Start installation?", detail) {
		printfln(colorRed, "\n  Installation aborted.")
		os.Exit(0)
	}
	inst.step = 2
}
