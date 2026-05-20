package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

var (
	modeFlag = flag.String("mode", "hud", "Operating mode: hud, installer, login")
)



func main() {
	flag.Parse()

	// If in HUD mode, ensure the Python backend is running
	if *modeFlag == "hud" {
		fmt.Println("Starting GingerOS backend...")

		// Launch the python server
		// We run it as a detached child process so it can outlive the UI if needed,
		// or we can clean it up on exit. For now, we will kill it when the TUI exits.
		// Wait, if it's the HUD, we probably want to kill the backend if we exit gracefully,
		// or let it run in the background. Let's make it a child process that we clean up.
		
		// Find the server script relative to the executable or CWD
		var serverScript string
		if _, err := os.Stat("server/main.py"); err == nil {
			serverScript = "server/main.py"
		} else if _, err := os.Stat("../../server/main.py"); err == nil {
			serverScript = "../../server/main.py"
		} else if _, err := os.Stat("../server/main.py"); err == nil {
			serverScript = "../server/main.py"
		}

		if serverScript != "" {
			// Find python executable in virtual env relative to workspace root or CWD
			var pythonPath = "python3"
			if _, err := os.Stat(".venv/bin/python3"); err == nil {
				pythonPath = ".venv/bin/python3"
			} else if _, err := os.Stat("../../.venv/bin/python3"); err == nil {
				pythonPath = "../../.venv/bin/python3"
			} else if _, err := os.Stat("../.venv/bin/python3"); err == nil {
				pythonPath = "../.venv/bin/python3"
			}

			cmd := exec.Command(pythonPath, serverScript)
			// Send output to a log file instead of stdout to avoid messing up the TUI
			logFile, err := os.OpenFile("backend.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
			if err == nil {
				cmd.Stdout = logFile
				cmd.Stderr = logFile
			}
			
			if err := cmd.Start(); err != nil {
				log.Fatalf("Failed to start backend: %v", err)
			}
			
			// Clean up child process on exit
			defer func() {
				cmd.Process.Kill()
			}()
			
			// Give the server a moment to bind to the port
			time.Sleep(1 * time.Second)
		} else {
			fmt.Println("Warning: server/main.py not found. Assuming backend is running elsewhere.")
		}
	}

	p := tea.NewProgram(newModel(*modeFlag), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		log.Fatalf("Error running program: %v", err)
	}
}
