package main

import (
	"fmt"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"
)

// deployer drives the 5-step installation against the selected target disk.
type deployer struct {
	inst      *installer
	targetDev string
	rootPart  string
	mnt       string
	flushed   bool
}

// runInstall runs the full deployment sequence, rendering live progress.
func (inst *installer) runInstall() {
	steps := []string{"Partitioning", "Extract Filesystem", "Hardware Sync", "User Setup", "Bootloader"}
	d := &deployer{
		inst:      inst,
		targetDev: inst.targetDev,
		rootPart:  inst.targetDev + "1",
		mnt:       "/mnt/ginger",
	}

	render := func(current int, status string) {
		fmt.Print(clearScreen)
		frame("GingerOS Installer v"+installerVersion+" · Deploying", []string{})
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

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM, syscall.SIGQUIT)
	go func() {
		sig := <-sigCh
		dl.logf("SIGNAL %v received, flushing data before exit", sig)
		fmt.Printf("\n\n  Received signal %v. Flushing data before exit...\n", sig)
		d.flush()
		fmt.Println("  Installer interrupted. Target disk may be incomplete.")
		os.Exit(130)
	}()

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

	if err := step(1, "Partitioning", d.stepPartition); err != nil {
		os.Exit(1)
	}
	if err := step(2, "Extract Filesystem", d.stepExtract); err != nil {
		os.Exit(1)
	}
	if err := step(3, "Hardware Sync", d.stepHardware); err != nil {
		os.Exit(1)
	}
	if err := step(4, "User Setup", d.stepUsers); err != nil {
		os.Exit(1)
	}
	if err := step(5, "Bootloader", d.stepBootloader); err != nil {
		os.Exit(1)
	}

	d.flush()
	inst.step = len(stepTitles)
}
