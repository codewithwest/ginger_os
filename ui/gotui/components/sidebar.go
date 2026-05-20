package components

import (
	"encoding/json"
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/codewithwest/ginger_os/ui/gotui/network"
	"github.com/codewithwest/ginger_os/ui/gotui/theme"
)

type Step struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	Phase    string  `json:"phase"`
	Status   string  `json:"status"`
	Progress int     `json:"progress"`
	Duration float64 `json:"duration"`
}

type StorageStats struct {
	Percent float64 `json:"percent"`
	UsedGB  float64 `json:"used_gb"`
	TotalGB float64 `json:"total_gb"`
}

type StatusPayload struct {
	Status        string                  `json:"status"`
	Running       bool                    `json:"running"`
	ExecutingStep *int                    `json:"executing_step"`
	CurrentPkg    string                  `json:"current_pkg"`
	Steps         []Step                  `json:"steps"`
	Storage       map[string]StorageStats `json:"storage"`
	Cores         int                     `json:"cores"`
	MaxCores      int                     `json:"max_cores"`
	CPUUsage      float64                 `json:"cpu_usage"`
	Timers        map[string]float64      `json:"timers"`
}

type SidebarModel struct {
	width, height int
	status        StatusPayload
	selectedIdx   int
	initialized   bool
}

func NewSidebarModel() SidebarModel {
	return SidebarModel{}
}

func (m SidebarModel) Init() tea.Cmd {
	return network.FetchStatus()
}

func (m SidebarModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	case network.SystemStatusMsg:
		var payload StatusPayload
		if err := json.Unmarshal(msg.Raw, &payload); err == nil {
			m.status = payload
			if !m.initialized {
				m.initialized = true
				if payload.ExecutingStep != nil {
					m.selectedIdx = *payload.ExecutingStep
				}
			}
		}
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.selectedIdx > 0 {
				m.selectedIdx--
			}
		case "down", "j":
			if m.selectedIdx < len(m.status.Steps)-1 {
				m.selectedIdx++
			}
		case "enter":
			if m.status.ExecutingStep != nil {
				break
			}
			if m.selectedIdx >= 0 && m.selectedIdx < len(m.status.Steps) {
				step := m.status.Steps[m.selectedIdx]
				if step.Status != "completed" && step.Status != "running" {
					cmds = append(cmds, network.RunStep(m.selectedIdx))
				}
			}
		case "f":
			if m.status.ExecutingStep != nil {
				break
			}
			if m.selectedIdx >= 0 && m.selectedIdx < len(m.status.Steps) {
				cmds = append(cmds, network.ForceStep(m.selectedIdx))
			}
		}
	}
	return m, tea.Batch(cmds...)
}

func (m SidebarModel) View() string {
	if m.width == 0 {
		return ""
	}

	logoASCII := `  _____ _                         ____   ______
 / ____(_)                       / __ \ / ____|
| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ 
| | |_ | | '_ \ / _` + "`" + ` |/ _ \ '__|| |  | |\___ \
| |__| | | | | | (_| |  __/ |   | |__| |____) |
 \_____|_|_| |_|\__, |\___|_|    \____/|_____/ 
                 __/ |                         
                |___/         v1.0.0`

	// 1. Branding
	var branding string
	if m.height >= 35 && m.width >= 50 {
		branding = lipgloss.NewStyle().
			Bold(true).
			Foreground(theme.ActiveTheme.Primary).
			Border(lipgloss.RoundedBorder()).
			BorderForeground(theme.ActiveTheme.Primary).
			Width(m.width - 2).
			Render(logoASCII)
	} else {
		branding = lipgloss.NewStyle().
			Bold(true).
			Foreground(theme.ActiveTheme.Primary).
			Border(lipgloss.RoundedBorder()).
			BorderForeground(theme.ActiveTheme.Primary).
			Width(m.width - 2).
			Render(" GINGER_OS // TACTICAL_HUD ")
	}
	brandingHeight := lipgloss.Height(branding)

	// 2. Neural Core / Timers
	neuralContent := "NEURAL_CORE_READY"
	if m.status.ExecutingStep != nil && *m.status.ExecutingStep < len(m.status.Steps) {
		step := m.status.Steps[*m.status.ExecutingStep]
		neuralContent = lipgloss.JoinVertical(lipgloss.Left,
			lipgloss.NewStyle().Foreground(theme.ActiveTheme.Error).Render("🚀 SYSTEM_BUSY"),
			fmt.Sprintf("MODULE: %s", step.Name),
			fmt.Sprintf("PKG:    %s", m.status.CurrentPkg),
			fmt.Sprintf("UPTIME: %.1fs", m.status.Timers["overall"]),
		)
	} else {
		neuralContent = lipgloss.JoinVertical(lipgloss.Left,
			lipgloss.NewStyle().Foreground(theme.ActiveTheme.Success).Render("🟢 NEURAL_CORE_READY"),
			"Awaiting operator command...",
		)
	}

	neuralBox := theme.BorderStyle().Width(m.width - 2).Render(neuralContent)
	neuralBoxHeight := lipgloss.Height(neuralBox)

	// 3. SYS_MX (Telemetry)
	sysContent := lipgloss.JoinVertical(lipgloss.Left,
		lipgloss.NewStyle().Bold(true).Foreground(theme.ActiveTheme.Text).Render(" 🖥️ HOST_NODE"),
		fmt.Sprintf("  CPU:   %.1f%%", m.status.CPUUsage),
		fmt.Sprintf("  CORES: %d/%d", m.status.Cores, m.status.MaxCores),
		"",
		lipgloss.NewStyle().Bold(true).Foreground(theme.ActiveTheme.Text).Render(" 💾 STORAGE"),
	)

	var storages []string
	for k, v := range m.status.Storage {
		color := theme.ActiveTheme.Success
		if v.Percent > 80 {
			color = theme.ActiveTheme.Error
		} else if v.Percent > 60 {
			color = theme.ActiveTheme.Warning
		}

		keyName := strings.ToUpper(k)
		if len(keyName) > 6 {
			keyName = keyName[:6]
		}

		percentStr := lipgloss.NewStyle().Foreground(color).Render(fmt.Sprintf("%5.1f%%", v.Percent))

		var storageLine string
		if m.width >= 40 {
			storageLine = fmt.Sprintf("  %-6s: %s [%.1f/%.0fGB]", keyName, percentStr, v.UsedGB, v.TotalGB)
		} else {
			storageLine = fmt.Sprintf("  %-6s: %s", keyName, percentStr)
		}
		storages = append(storages, storageLine)
	}

	sysContent = lipgloss.JoinVertical(lipgloss.Left, sysContent, strings.Join(storages, "\n"))
	sysBox := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(theme.ActiveTheme.Primary).
		Width(m.width - 2).
		Render(sysContent)
	sysBoxHeight := lipgloss.Height(sysBox)

	// 4. Calculate exact remaining height for steps pipeline, minus 2 lines for stepsBox borders
	listHeight := m.height - brandingHeight - neuralBoxHeight - sysBoxHeight - 2
	if listHeight < 3 {
		listHeight = 3
	}

	// 5. Steps List
	var stepLines []string
	for i, step := range m.status.Steps {
		prefix := "  "
		if i == m.selectedIdx {
			prefix = "> "
		}

		statusColor := theme.ActiveTheme.Text
		statusText := "◐ PENDING"
		switch step.Status {
		case "completed":
			statusColor = theme.ActiveTheme.Success
			statusText = "✔ COMPLETE"
		case "failed":
			statusColor = theme.ActiveTheme.Error
			statusText = "✘ FAILED"
		case "running":
			statusColor = theme.ActiveTheme.Primary
			statusText = "▶ RUNNING"
		}

		nameWidth := m.width - 20
		if nameWidth < 8 {
			nameWidth = 8
		}

		displayName := step.Name
		if len(displayName) > 4 && displayName[2] == '.' && displayName[3] == ' ' {
			displayName = displayName[4:]
		}
		if len(displayName) > nameWidth {
			displayName = displayName[:nameWidth-3] + "..."
		}

		idxStr := lipgloss.NewStyle().Foreground(theme.ActiveTheme.Primary).Render(fmt.Sprintf("%02d", i+1))
		nameStr := lipgloss.NewStyle().Width(nameWidth).Render(displayName)
		statStr := lipgloss.NewStyle().Foreground(statusColor).Render(statusText)

		line := fmt.Sprintf("%s%s %s %s", prefix, idxStr, nameStr, statStr)
		if i == m.selectedIdx {
			line = lipgloss.NewStyle().Background(theme.ActiveTheme.Bg).Render(line)
		}
		stepLines = append(stepLines, line)
	}

	var visibleSteps []string
	if len(stepLines) > listHeight {
		start := m.selectedIdx - listHeight/2
		if start < 0 {
			start = 0
		}
		end := start + listHeight
		if end > len(stepLines) {
			end = len(stepLines)
			start = end - listHeight
		}
		if start < 0 {
			start = 0
		}
		visibleSteps = stepLines[start:end]
	} else {
		visibleSteps = stepLines
	}

	stepsBox := theme.BorderStyle().Width(m.width - 2).Height(listHeight).Render(strings.Join(visibleSteps, "\n"))

	return lipgloss.JoinVertical(lipgloss.Left, branding, neuralBox, stepsBox, sysBox)
}

// ExecutingStep returns the current executing step index or nil
func (m SidebarModel) ExecutingStep() *int {
	return m.status.ExecutingStep
}

// TotalSteps returns the total steps count
func (m SidebarModel) TotalSteps() int {
	return len(m.status.Steps)
}
