package components

import (
	"os"
	"os/exec"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/codewithwest/ginger_os/ui/gotui/theme"
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
			scriptPath := "../../lfs/chroot.sh"

			if _, err := os.Stat("/mnt/ginger_lfs/bin/bash"); os.IsNotExist(err) {
				c := exec.Command("bash", "-c", "echo '\n[ERROR] /mnt/ginger_lfs/bin/bash does not exist.'; echo 'The LFS environment is not ready for chroot yet.'; echo 'Press Enter to return...'; read")
				c.Stdin = os.Stdin
				c.Stdout = os.Stdout
				c.Stderr = os.Stderr
				return m, tea.ExecProcess(c, func(err error) tea.Msg { return nil })
			}

			var c *exec.Cmd
			if _, err := os.Stat(scriptPath); err == nil {
				c = exec.Command("sudo", "bash", scriptPath)
			} else {
				c = exec.Command("sudo", "chroot", "/mnt/ginger_lfs", "/usr/bin/env", "-i", "HOME=/root", "TERM="+os.Getenv("TERM"), "PS1=(lfs-debug) \\u:\\w\\$ ", "PATH=/bin:/usr/bin:/sbin:/usr/sbin", "/bin/bash", "--login")
			}

			c.Stdin = os.Stdin
			c.Stdout = os.Stdout
			c.Stderr = os.Stderr
			return m, tea.ExecProcess(c, func(err error) tea.Msg {
				return nil
			})
		}
	}
	return m, nil
}

func (m DebugModel) View() string {
	box := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(theme.ActiveTheme.Error).
		Padding(1, 2).
		Align(lipgloss.Center)

	content := lipgloss.JoinVertical(lipgloss.Center,
		theme.TitleStyle().Foreground(theme.ActiveTheme.Error).Render("LFS DEBUG CONSOLE"),
		"",
		"Press ENTER to drop into an interactive root shell.",
		"Type 'exit' to return to the HUD.",
	)

	if m.width > 0 && m.height > 0 {
		return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, box.Render(content))
	}

	return box.Render(content)
}
