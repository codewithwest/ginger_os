package main

import (
	"fmt"
	"os"
	"strings"
)

type installer struct {
	targetDev    string
	username     string
	password     string
	rootPassword string
	step         int
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
