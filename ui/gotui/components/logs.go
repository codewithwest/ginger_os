package components

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/codewithwest/ginger_os/ui/gotui/network"
	"github.com/codewithwest/ginger_os/ui/gotui/theme"
)

type LogsModel struct {
	viewport viewport.Model
	logs     []string
	width    int
	height   int
	status   StatusPayload
}

func NewLogsModel() LogsModel {
	vp := viewport.New(0, 0)
	vp.YPosition = 0
	return LogsModel{
		viewport: vp,
		logs:     []string{"Initializing quantum log stream..."},
	}
}

func (m LogsModel) Init() tea.Cmd {
	network.StartLogListener()
	return network.WaitForLog
}

func (m LogsModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.viewport.Width = msg.Width - 4
		m.viewport.Height = msg.Height - 5 // Space for bannerBox (3) + logBox borders (2)
		m.viewport.SetContent(strings.Join(m.logs, "\n"))

	case network.SystemStatusMsg:
		var payload StatusPayload
		if err := json.Unmarshal(msg.Raw, &payload); err == nil {
			m.status = payload
		}

	case network.LogMsg:
		// Format the incoming log based on style
		formattedMsg := msg.Msg
		if msg.Style != "" {
			style := lipgloss.NewStyle()
			if strings.Contains(msg.Style, "red") {
				style = style.Foreground(theme.ActiveTheme.Error)
			} else if strings.Contains(msg.Style, "green") {
				style = style.Foreground(theme.ActiveTheme.Success)
			} else if strings.Contains(msg.Style, "yellow") {
				style = style.Foreground(theme.ActiveTheme.Warning)
			} else if strings.Contains(msg.Style, "cyan") {
				style = style.Foreground(theme.ActiveTheme.Primary)
			} else {
				style = style.Foreground(theme.ActiveTheme.Text)
			}
			if strings.Contains(msg.Style, "bold") {
				style = style.Bold(true)
			}
			formattedMsg = style.Render(msg.Msg)
		} else {
			formattedMsg = lipgloss.NewStyle().Foreground(theme.ActiveTheme.Text).Render(msg.Msg)
		}

		m.logs = append(m.logs, formattedMsg)
		if len(m.logs) > 1000 {
			m.logs = m.logs[len(m.logs)-1000:]
		}
		
		m.viewport.SetContent(strings.Join(m.logs, "\n"))
		m.viewport.GotoBottom()
		
		cmds = append(cmds, network.WaitForLog)
	}

	// Route unhandled messages (like keyboard scrolling) to the viewport,
	// except up/down/j/k navigation which is reserved for the steps list.
	var vpCmd tea.Cmd
	shouldScrollLogs := true
	if keyMsg, ok := msg.(tea.KeyMsg); ok {
		k := keyMsg.String()
		if k == "up" || k == "down" || k == "j" || k == "k" {
			shouldScrollLogs = false
		}
	}

	if shouldScrollLogs {
		m.viewport, vpCmd = m.viewport.Update(msg)
		cmds = append(cmds, vpCmd)
	}

	return m, tea.Batch(cmds...)
}

func (m LogsModel) View() string {
	if m.width == 0 {
		return ""
	}

	var banner string
	if m.status.ExecutingStep != nil {
		activePhase := "N/A"
		if *m.status.ExecutingStep < len(m.status.Steps) {
			activePhase = m.status.Steps[*m.status.ExecutingStep].Phase
		}
		
		pkgStr := "N/A"
		if m.status.CurrentPkg != "" {
			pkgStr = m.status.CurrentPkg
		}
		
		banner = fmt.Sprintf(
			" 🌀 PHASE: %s [%.1fs] │ 📦 PKG: %s [%.1fs] │ ⏱️ OVERALL: %.1fs ",
			lipgloss.NewStyle().Foreground(theme.ActiveTheme.Primary).Bold(true).Render(activePhase),
			m.status.Timers["phase"],
			lipgloss.NewStyle().Foreground(theme.ActiveTheme.Warning).Bold(true).Render(pkgStr),
			m.status.Timers["package"],
			m.status.Timers["overall"],
		)
	} else {
		banner = fmt.Sprintf(
			" 🟢 SYSTEM READY │ ⏱️ OVERALL UPTIME: %.1fs ",
			m.status.Timers["overall"],
		)
	}
	
	bannerBox := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(theme.ActiveTheme.Primary).
		Width(m.width - 2).
		Render(banner)

	box := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(theme.ActiveTheme.Primary).
		Padding(0, 1).
		Width(m.width - 2).
		Height(m.height - 5) // Height subtracts 3 for bannerBox and 2 for borders

	logBox := box.Render(m.viewport.View())

	return lipgloss.JoinVertical(lipgloss.Left, bannerBox, logBox)
}
