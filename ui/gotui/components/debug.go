package components

import (
	"os"
	"os/exec"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type DebugModel struct {
	width, height int
}

func NewDebugModel() DebugModel {
	return DebugModel{}
}

func (m DebugModel) Init() tea.Cmd {
	return nil
}

func (m DebugModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	case tea.KeyMsg:
		switch msg.String() {
		case "enter":
			// First, check if we can actually chroot. If lfs/chroot.sh exists, use it.
			// The TUI is running from ui/gotui, so lfs/chroot.sh is at ../../lfs/chroot.sh
			scriptPath := "../../lfs/chroot.sh"
			
			// Verify if /mnt/ginger_lfs/bin/bash exists, if not, chroot won't work
			if _, err := os.Stat("/mnt/ginger_lfs/bin/bash"); os.IsNotExist(err) {
				// Fallback to a shell command that prints the error and waits
				c := exec.Command("bash", "-c", "echo '\n[ERROR] /mnt/ginger_lfs/bin/bash does not exist.'; echo 'The LFS environment is not ready for chroot yet.'; echo 'Press Enter to return...'; read")
				c.Stdin = os.Stdin
				c.Stdout = os.Stdout
				c.Stderr = os.Stderr
				return m, tea.ExecProcess(c, func(err error) tea.Msg { return nil })
			}

			var c *exec.Cmd
			if _, err := os.Stat(scriptPath); err == nil {
				// Use the official chroot script to handle mounts safely
				c = exec.Command("sudo", "bash", scriptPath)
			} else {
				// Fallback raw chroot
				c = exec.Command("sudo", "chroot", "/mnt/ginger_lfs", "/usr/bin/env", "-i", "HOME=/root", "TERM="+os.Getenv("TERM"), "PS1=(lfs-debug) \\u:\\w\\$ ", "PATH=/bin:/usr/bin:/sbin:/usr/sbin", "/bin/bash", "--login")
			}
			
			c.Stdin = os.Stdin
			c.Stdout = os.Stdout
			c.Stderr = os.Stderr
			return m, tea.ExecProcess(c, func(err error) tea.Msg {
				return nil // Ignore error or handle it
			})
		}
	}
	return m, nil
}

func (m DebugModel) View() string {
	box := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("#ff003c")).
		Padding(1, 2).
		Align(lipgloss.Center)

	content := lipgloss.JoinVertical(lipgloss.Center,
		lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#ff003c")).Render("LFS DEBUG CONSOLE"),
		"",
		"Press ENTER to drop into an interactive root shell.",
		"Type 'exit' to return to the HUD.",
	)

	// Center the box if we have dimensions
	if m.width > 0 && m.height > 0 {
		return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, box.Render(content))
	}

	return box.Render(content)
}
