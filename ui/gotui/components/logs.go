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

const scrollbarWidth = 2

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
		logs:     []string{},
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
		m.viewport.Height = msg.Height - 5
		m.viewport.SetContent(strings.Join(m.logs, "\n"))

	case network.SystemStatusMsg:
		var payload StatusPayload
		if err := json.Unmarshal(msg.Raw, &payload); err == nil {
			m.status = payload
		}

	case network.ErrorMsg:
		logLine := lipgloss.NewStyle().
			Foreground(theme.ActiveTheme.Error).
			Bold(true).
			Render(fmt.Sprintf(" ✗ %v", msg.Err))
		m.logs = append(m.logs, logLine)
		if len(m.logs) > 1000 {
			m.logs = m.logs[len(m.logs)-1000:]
		}
		m.viewport.SetContent(strings.Join(m.logs, "\n"))
		if m.viewport.AtBottom() {
			m.viewport.GotoBottom()
		}

	case network.LogMsg:
		var formattedMsg string
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
			formattedMsg = theme.BaseStyle().Render(msg.Msg)
		}

		m.logs = append(m.logs, formattedMsg)
		if len(m.logs) > 1000 {
			m.logs = m.logs[len(m.logs)-1000:]
		}

		m.viewport.SetContent(strings.Join(m.logs, "\n"))
		if m.viewport.AtBottom() {
			m.viewport.GotoBottom()
		}
	}

	cmds = append(cmds, network.WaitForLog)

	// Don't forward arrow keys to viewport — reserved for sidebar step nav
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "down", "k", "j":
		default:
			m.viewport, _ = m.viewport.Update(msg)
		}
	default:
		m.viewport, _ = m.viewport.Update(msg)
	}

	return m, tea.Batch(cmds...)
}

func (m LogsModel) View() string {
	if m.width == 0 {
		return ""
	}

	running := m.status.ExecutingStep != nil

	statusDot := lipgloss.NewStyle().Foreground(theme.ActiveTheme.Success).Render("●")
	statusLabel := "STANDBY"
	if running {
		statusDot = lipgloss.NewStyle().Foreground(theme.ActiveTheme.Error).Render("●")
		statusLabel = "ACTIVE"
	}

	bannerParts := []string{
		lipgloss.NewStyle().Foreground(theme.ActiveTheme.TextDim).Render("  LOG FEED"),
		statusDot,
		lipgloss.NewStyle().Foreground(theme.ActiveTheme.TextDim).Render(statusLabel),
	}

	if running && m.status.ExecutingStep != nil && *m.status.ExecutingStep < len(m.status.Steps) {
		step := m.status.Steps[*m.status.ExecutingStep]
		pkgStr := m.status.CurrentPkg
		if pkgStr == "" {
			pkgStr = "—"
		}
		bannerParts = append(bannerParts,
			lipgloss.NewStyle().Foreground(theme.ActiveTheme.Border).Render("│"),
			lipgloss.NewStyle().Foreground(theme.ActiveTheme.TextDim).Render("PKG"),
			lipgloss.NewStyle().Foreground(theme.ActiveTheme.Warning).Bold(true).Render(pkgStr),
			lipgloss.NewStyle().Foreground(theme.ActiveTheme.Border).Render("│"),
			lipgloss.NewStyle().Foreground(theme.ActiveTheme.TextDim).Render("PHASE"),
			theme.TitleStyle().Render(step.Phase),
		)
	}

	banner := lipgloss.NewStyle().Render(strings.Join(bannerParts, " "))

	bannerBox := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(theme.ActiveTheme.Border).
		Width(m.width-2).
		Padding(0, 1).
		Render(banner)

	box := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(theme.ActiveTheme.Border).
		Padding(0, 1).
		Width(m.width - 2).
		Height(m.height - 5)

	viewportContent := m.viewport.View()
	if viewportContent == "" {
		viewportContent = "\n  " + lipgloss.NewStyle().Foreground(theme.ActiveTheme.TextDim).Render("Awaiting output from build pipeline...")
	}

	logBox := box.Render(viewportContent)

	return lipgloss.JoinVertical(lipgloss.Left, bannerBox, logBox)
}
