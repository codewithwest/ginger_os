package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/codewithwest/ginger_os/ui/gotui/network"
	"github.com/codewithwest/ginger_os/ui/gotui/theme"
)

var (
	modeFlag  = flag.String("mode", "hud", "Operating mode: hud, installer, login")
	themeFlag = flag.String("theme", "cyberpunk", "Theme: cyberpunk, dracula, catppuccin")
)

func backendRunning() bool {
	conn, err := net.DialTimeout("tcp", "localhost:8087", 500*time.Millisecond)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}

func main() {
	flag.Parse()

	theme.SetTheme(*themeFlag)

	if *modeFlag == "hud" {
		if !backendRunning() {
			fmt.Println("Starting GingerOS backend...")

			var serverScript string
			candidates := []string{"server/main.py", "../../server/main.py", "../server/main.py"}
			for _, c := range candidates {
				if _, err := os.Stat(c); err == nil {
					serverScript = c
					break
				}
			}

			if serverScript != "" {
				var pythonPath = "python3"
				pyCandidates := []string{".venv/bin/python3", "../../.venv/bin/python3", "../.venv/bin/python3"}
				for _, c := range pyCandidates {
					if _, err := os.Stat(c); err == nil {
						pythonPath = c
						break
					}
				}

				cmd := exec.Command(pythonPath, serverScript)
				logFile, err := os.OpenFile("backend.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
				if err == nil {
					cmd.Stdout = logFile
					cmd.Stderr = logFile
				}

				if err := cmd.Start(); err != nil {
					log.Fatalf("Failed to start backend: %v", err)
				}

				defer func() {
					network.StopLogListener()
					cmd.Process.Kill()
				}()

				// Wait for backend to bind
				for i := 0; i < 10; i++ {
					if backendRunning() {
						break
					}
					time.Sleep(300 * time.Millisecond)
				}
				if !backendRunning() {
					fmt.Println("Warning: Backend may not have started. Check backend.log")
				}
			} else {
				fmt.Println("Warning: server/main.py not found. Assuming backend is running elsewhere.")
			}
		}
	}

	p := tea.NewProgram(newModel(*modeFlag), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		log.Fatalf("Error running program: %v", err)
	}
	network.StopLogListener()
}
