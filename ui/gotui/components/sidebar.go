package components

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

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
	width, height  int
	status         StatusPayload
	selectedIdx    int
	initialized    bool
	connectionErr  error
	connectionOK   bool
	lastUpdate     time.Time
	confirmAction  string
	parallelPhase3 string
}

func NewSidebarModel() SidebarModel {
	return SidebarModel{
		connectionOK:   true,
		parallelPhase3: "false",
	}
}

func (m SidebarModel) Init() tea.Cmd {
	return tea.Batch(network.FetchStatus(), network.FetchConfig())
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
			m.connectionErr = nil
			m.connectionOK = true
			m.lastUpdate = time.Now()
			if !m.initialized {
				m.initialized = true
				if payload.ExecutingStep != nil {
					m.selectedIdx = *payload.ExecutingStep
				}
			}
			// Advance selection to next pending step when current completes
			if payload.ExecutingStep == nil && !payload.Running {
				selStatus := ""
				if m.selectedIdx < len(payload.Steps) {
					selStatus = payload.Steps[m.selectedIdx].Status
				}
				if selStatus == "completed" {
					for i, s := range payload.Steps {
						if s.Status != "completed" {
							m.selectedIdx = i
							break
						}
					}
				}
			}
		}
	case network.ErrorMsg:
		if m.connectionOK {
			m.connectionErr = msg.Err
			m.connectionOK = false
		}
	case network.ConfigMsg:
		if v, ok := msg.Config["PARALLEL_PHASE3"]; ok {
			m.parallelPhase3 = v
		}
	case network.ActionSuccessMsg:
		if m.confirmAction != "" {
			m.confirmAction = ""
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
			if m.confirmAction != "" {
				action := m.confirmAction
				m.confirmAction = ""
				switch action {
				case "run":
					if m.selectedIdx >= 0 && m.selectedIdx < len(m.status.Steps) {
						cmds = append(cmds, network.RunStep(m.selectedIdx))
					}
				case "force":
					if m.selectedIdx >= 0 && m.selectedIdx < len(m.status.Steps) {
						cmds = append(cmds, network.ForceStep(m.selectedIdx))
					}
				case "abort":
					cmds = append(cmds, network.ControlAction("abort"))
				case "quit":
					return m, tea.Quit
				}
			} else if m.status.ExecutingStep == nil {
				if m.selectedIdx >= 0 && m.selectedIdx < len(m.status.Steps) {
					step := m.status.Steps[m.selectedIdx]
					if step.Status == "completed" {
						m.confirmAction = "force"
					} else if step.Status != "running" {
						m.confirmAction = "run"
					}
				}
			}
		case "esc":
			m.confirmAction = ""
		case "f":
			if m.confirmAction != "" {
				m.confirmAction = ""
			} else if m.status.ExecutingStep == nil {
				if m.selectedIdx >= 0 && m.selectedIdx < len(m.status.Steps) {
					m.confirmAction = "force"
				}
			}
		case "p":
			if m.confirmAction == "" {
				newVal := "true"
				if m.parallelPhase3 == "true" {
					newVal = "false"
				}
				m.parallelPhase3 = newVal
				cmds = append(cmds, network.SetConfig("PARALLEL_PHASE3", newVal))
			}
		}
	}
	return m, tea.Batch(cmds...)
}

func renderMiniBar(percent float64, color lipgloss.Color, width int) string {
	if width < 4 {
		return ""
	}
	filled := int(percent * float64(width) / 100)
	if filled > width {
		filled = width
	}
	bar := strings.Repeat("█", filled) + strings.Repeat("░", width-filled)
	return lipgloss.NewStyle().Foreground(color).Render(bar)
}

func (m SidebarModel) View() string {
	if m.width == 0 {
		return ""
	}

	var sections []string
	w := m.width - 2
	if w < 4 {
		w = 4
	}

	// Connection warning
	if !m.connectionOK {
		warnStyle := lipgloss.NewStyle().
			Background(theme.ActiveTheme.Error).
			Foreground(theme.ActiveTheme.Bg).
			Bold(true).
			Width(w).
			Align(lipgloss.Center)
		lastUpdateStr := ""
		if !m.lastUpdate.IsZero() {
			lastUpdateStr = fmt.Sprintf(" (last update: %s ago)", time.Since(m.lastUpdate).Round(time.Second))
		}
		sections = append(sections, warnStyle.Render(fmt.Sprintf("✗ BACKEND DISCONNECTED%s", lastUpdateStr)))
	}

	// 1. Branding
	logoASCII := "      _                            \n __ _(_)_ _  __ _ ___ _ _   ___ ___\n/ _` | | ' \\/ _` / -_) '_| / _ (_-<\n\\__, |_|_||_\\__, \\___|_|   \\___/__/\n|___/       |___/                  "

	var branding string
	if m.height >= 35 && m.width >= 50 {
		branding = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(theme.ActiveTheme.Primary).
			Width(w).
			Render(lipgloss.NewStyle().Foreground(theme.ActiveTheme.Primary).Render(logoASCII))
	} else {
		branding = theme.BorderStyle().Width(w).Render(
			lipgloss.NewStyle().Foreground(theme.ActiveTheme.Primary).Bold(true).Render(" GINGER_OS "),
		)
	}
	sections = append(sections, branding)

	// 2. Status box
	statusContent := ""
	if m.status.ExecutingStep != nil && *m.status.ExecutingStep < len(m.status.Steps) {
		step := m.status.Steps[*m.status.ExecutingStep]
		statusContent = lipgloss.JoinVertical(lipgloss.Left,
			lipgloss.NewStyle().Foreground(theme.ActiveTheme.Error).Bold(true).Render(" ● BUILD IN PROGRESS"),
			"",
			fmt.Sprintf("  Module  %s", theme.DimStyle().Render(step.Name)),
			fmt.Sprintf("  Package %s", lipgloss.NewStyle().Foreground(theme.ActiveTheme.Warning).Bold(true).Render(m.status.CurrentPkg)),
			fmt.Sprintf("  Uptime  %s", lipgloss.NewStyle().Foreground(theme.ActiveTheme.Primary).Render(fmt.Sprintf("%.1fs", m.status.Timers["overall"]))),
		)
	} else {
		statusContent = lipgloss.JoinVertical(lipgloss.Left,
			lipgloss.NewStyle().Foreground(theme.ActiveTheme.Success).Bold(true).Render(" ◆ SYSTEM IDLE"),
			"",
			fmt.Sprintf("  %s", theme.DimStyle().Render("Awaiting operator command...")),
		)
	}
	sections = append(sections, lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(theme.ActiveTheme.Border).
		Width(w).
		Padding(0, 1).
		Render(statusContent))

	// 2.5 Confirmation dialog
	if m.confirmAction != "" {
		confirmMsg := ""
		switch m.confirmAction {
		case "run":
			confirmMsg = "Run this step?"
		case "force":
			confirmMsg = "Force run this step?"
		case "abort":
			confirmMsg = "Abort current build?"
		case "quit":
			confirmMsg = "Quit GingerOS HUD?"
		}
		confirmBox := lipgloss.NewStyle().
			Background(theme.ActiveTheme.Warning).
			Foreground(theme.ActiveTheme.Bg).
			Bold(true).
			Width(w).
			Align(lipgloss.Center).
			Render(fmt.Sprintf(" %s [ENTER=confirm / ESC=cancel] ", confirmMsg))
		sections = append(sections, confirmBox)
	}

	// 3. Telemetry
	parallelColor := theme.ActiveTheme.Success
	parallelLabel := "ENABLED"
	if m.parallelPhase3 != "true" {
		parallelColor = theme.ActiveTheme.TextDim
		parallelLabel = "OFF"
	}

	barWidth := w - 16
	if barWidth < 4 {
		barWidth = 4
	}

	telemetryContent := lipgloss.JoinVertical(lipgloss.Left,
		lipgloss.NewStyle().Foreground(theme.ActiveTheme.Primary).Bold(true).Render(" ⚙ HOST NODE"),
		"",
		fmt.Sprintf("  CPU  %s  %s",
			renderMiniBar(m.status.CPUUsage, theme.ActiveTheme.Primary, barWidth),
			lipgloss.NewStyle().Foreground(theme.ActiveTheme.Primary).Render(fmt.Sprintf("%5.1f%%", m.status.CPUUsage)),
		),
		fmt.Sprintf("  CORES %d/%d", m.status.Cores, m.status.MaxCores),
		fmt.Sprintf("  PAR   %s", lipgloss.NewStyle().Foreground(parallelColor).Render(parallelLabel)),
	)

	// Storage bars
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

		bar := renderMiniBar(v.Percent, color, barWidth-6)
		telemetryContent = lipgloss.JoinVertical(lipgloss.Left,
			telemetryContent,
			fmt.Sprintf("  %-6s %s %s",
				lipgloss.NewStyle().Foreground(theme.ActiveTheme.TextDim).Render(keyName),
				bar,
				lipgloss.NewStyle().Foreground(color).Render(fmt.Sprintf("%5.1f%%", v.Percent)),
			),
		)
	}

	sections = append(sections, lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(theme.ActiveTheme.Border).
		Width(w).
		Padding(0, 1).
		Render(telemetryContent))

	// 4. Steps pipeline
	listAreaHeight := m.height
	for _, s := range sections {
		listAreaHeight -= lipgloss.Height(s)
	}
	listAreaHeight -= 2
	if listAreaHeight < 3 {
		listAreaHeight = 3
	}

	nameWidth := w - 22
	if nameWidth < 8 {
		nameWidth = 8
	}

	var stepLines []string
	for i, step := range m.status.Steps {
		statusColor := theme.ActiveTheme.TextDim
		statusText := "PENDING"
		indicator := "○"
		borderColor := theme.ActiveTheme.Border
		switch step.Status {
		case "completed":
			statusColor = theme.ActiveTheme.Success
			statusText = "DONE"
			indicator = "●"
			borderColor = theme.ActiveTheme.Success
		case "failed":
			statusColor = theme.ActiveTheme.Error
			statusText = "FAIL"
			indicator = "●"
			borderColor = theme.ActiveTheme.Error
		case "running":
			statusColor = theme.ActiveTheme.Primary
			statusText = "RUN"
			indicator = "▶"
			borderColor = theme.ActiveTheme.Primary
		}

		displayName := step.Name
		if len(displayName) > 4 && displayName[2] == '.' && displayName[3] == ' ' {
			displayName = displayName[4:]
		}
		if len(displayName) > nameWidth {
			displayName = displayName[:nameWidth-3] + "..."
		}

		selectedMark := " "
		if i == m.selectedIdx {
			selectedMark = "▸"
		}

		idxStyle := lipgloss.NewStyle().Foreground(theme.ActiveTheme.TextDim)
		idxStr := idxStyle.Render(fmt.Sprintf("%02d", i+1))

		indicatorStr := lipgloss.NewStyle().Foreground(statusColor).Render(indicator)
		nameStr := lipgloss.NewStyle().Width(nameWidth).Render(displayName)
		statStr := lipgloss.NewStyle().Foreground(statusColor).Bold(true).Render(fmt.Sprintf("%4s", statusText))

		line := fmt.Sprintf("%s %s %s %s %s", selectedMark, idxStr, indicatorStr, nameStr, statStr)

		if step.Status == "running" && step.Progress > 0 {
			pbarWidth := nameWidth
			if pbarWidth > 0 {
				filled := step.Progress * pbarWidth / 100
				bar := lipgloss.NewStyle().Foreground(borderColor).Render(strings.Repeat("█", filled))
				rest := lipgloss.NewStyle().Foreground(theme.ActiveTheme.Border).Render(strings.Repeat("░", pbarWidth-filled))
				line += fmt.Sprintf("\n     %2d%% %s%s", step.Progress, bar, rest)
			}
		}

		if i == m.selectedIdx {
			highlight := lipgloss.NewStyle().Background(theme.ActiveTheme.BgAlt).PaddingLeft(1).Width(w + 1)
			line = highlight.Render(line)
		}

		stepLines = append(stepLines, "  "+line)
	}

	var visibleSteps []string
	if len(stepLines) > listAreaHeight {
		start := m.selectedIdx - listAreaHeight/2
		if start < 0 {
			start = 0
		}
		end := start + listAreaHeight
		if end > len(stepLines) {
			end = len(stepLines)
			start = end - listAreaHeight
		}
		if start < 0 {
			start = 0
		}
		visibleSteps = stepLines[start:end]
	} else {
		visibleSteps = stepLines
	}

	headerSpaces := nameWidth - 4
	if headerSpaces < 1 {
		headerSpaces = 1
	}
	titleLine := lipgloss.NewStyle().Foreground(theme.ActiveTheme.TextDim).Render(
		"     #    STEP" + strings.Repeat(" ", headerSpaces) + "STATUS",
	)

	stepsTitle := lipgloss.JoinVertical(lipgloss.Left,
		lipgloss.NewStyle().Foreground(theme.ActiveTheme.Primary).Bold(true).Render(" 📋 BUILD PIPELINE"),
		"",
		titleLine,
	)
	pipelineArea := lipgloss.JoinVertical(lipgloss.Left, stepsTitle, strings.Join(visibleSteps, "\n"))
	if len(visibleSteps) == 0 {
		pipelineArea = lipgloss.JoinVertical(lipgloss.Left, stepsTitle, theme.DimStyle().Render("  No pipeline data"))
	}

	sections = append(sections, lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(theme.ActiveTheme.Border).
		Width(w).
		Height(listAreaHeight).
		Padding(0, 1).
		Render(pipelineArea))

	// 5. Help footer
	helpStyle := lipgloss.NewStyle().
		Foreground(theme.ActiveTheme.TextDim).
		Width(w).
		Align(lipgloss.Center)
	helpText := helpStyle.Render("[p] parallel  [↑/↓] nav  [f] force  [ESC] cancel")

	allSections := append(sections, helpText)
	return lipgloss.JoinVertical(lipgloss.Left, allSections...)
}

func (m SidebarModel) ExecutingStep() *int {
	return m.status.ExecutingStep
}

func (m SidebarModel) TotalSteps() int {
	return len(m.status.Steps)
}

func (m SidebarModel) ConnectionOK() bool {
	return m.connectionOK
}
