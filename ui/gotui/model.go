package main

import (
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/codewithwest/ginger_os/ui/gotui/components"
	"github.com/codewithwest/ginger_os/ui/gotui/network"
	"github.com/codewithwest/ginger_os/ui/gotui/theme"
)

type Workspace int

const (
	LogsWorkspace Workspace = iota
	ChatWorkspace
	DebugWorkspace
)

type model struct {
	mode          string
	activeTab     Workspace
	debug         components.DebugModel
	sidebar       components.SidebarModel
	logsView      components.LogsModel
	width, height int
	confirmQuit   bool
}

func newModel(mode string) model {
	return model{
		mode:      mode,
		activeTab: LogsWorkspace,
		debug:     components.NewDebugModel(),
		sidebar:   components.NewSidebarModel(),
		logsView:  components.NewLogsModel(),
	}
}

type tickMsg time.Time

func tick() tea.Cmd {
	return tea.Tick(time.Second*2, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func (m model) Init() tea.Cmd {
	return tea.Batch(
		tea.EnterAltScreen,
		m.debug.Init(),
		m.sidebar.Init(),
		m.logsView.Init(),
		tick(),
	)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			if m.confirmQuit {
				network.StopLogListener()
				return m, tea.Quit
			}
			m.confirmQuit = true
		case "esc":
			m.confirmQuit = false
			// Pass esc to sidebar for confirmation cancel
			newSidebar, cmd := m.sidebar.Update(msg)
			m.sidebar = newSidebar.(components.SidebarModel)
			cmds = append(cmds, cmd)
		case "tab":
			m.confirmQuit = false
			if msg.Alt {
				if m.activeTab > 0 {
					m.activeTab--
				} else {
					m.activeTab = 2
				}
			} else {
				m.activeTab = (m.activeTab + 1) % 3
			}
		case "a":
			m.confirmQuit = false
			if m.sidebar.ExecutingStep() == nil {
				cmds = append(cmds, network.ControlAction("auto"))
			}
		case "x":
			m.confirmQuit = false
			if m.sidebar.ExecutingStep() != nil {
				cmds = append(cmds, network.ControlAction("abort"))
			}
		case "ctrl+s":
			m.confirmQuit = false
			cmds = append(cmds, network.TakeSnapshot("gotui_snapshot"))
		case "enter":
			if m.confirmQuit {
				network.StopLogListener()
				return m, tea.Quit
			}
		}

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height

		sidebarWidth := 50
		if m.width < 110 {
			sidebarWidth = int(float64(m.width) * 0.35)
			if sidebarWidth < 30 {
				sidebarWidth = 30
			}
		}
		mainWidth := m.width - sidebarWidth - 1

		sidebarMod, _ := m.sidebar.Update(tea.WindowSizeMsg{Width: sidebarWidth, Height: m.height - 1})
		m.sidebar = sidebarMod.(components.SidebarModel)

		debugMod, _ := m.debug.Update(tea.WindowSizeMsg{Width: mainWidth, Height: m.height - 3})
		m.debug = debugMod.(components.DebugModel)

		logsMod, _ := m.logsView.Update(tea.WindowSizeMsg{Width: mainWidth, Height: m.height - 3})
		m.logsView = logsMod.(components.LogsModel)

	case tickMsg:
		cmds = append(cmds, tick())
		cmds = append(cmds, m.sidebar.Init())
	}

	if _, ok := msg.(tea.WindowSizeMsg); !ok {
		newSidebar, cmd := m.sidebar.Update(msg)
		m.sidebar = newSidebar.(components.SidebarModel)
		cmds = append(cmds, cmd)

		newLogs, cmd2 := m.logsView.Update(msg)
		m.logsView = newLogs.(components.LogsModel)
		cmds = append(cmds, cmd2)
	}

	switch m.activeTab {
	case DebugWorkspace:
		newDebug, cmd := m.debug.Update(msg)
		m.debug = newDebug.(components.DebugModel)
		cmds = append(cmds, cmd)
	}

	return m, tea.Batch(cmds...)
}

func (m model) View() string {
	if m.width == 0 {
		return "Initializing..."
	}

	tabs := []string{"Logs", "Chat", "Debug"}
	var renderedTabs []string

	activeTabStyle := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder(), true, true, false, true).
		BorderForeground(theme.ActiveTheme.Primary).
		Foreground(theme.ActiveTheme.Primary).
		Padding(0, 1)

	inactiveTabStyle := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder(), true, true, false, true).
		BorderForeground(theme.ActiveTheme.Bg).
		Foreground(theme.ActiveTheme.Text).
		Padding(0, 1)

	for i, t := range tabs {
		if Workspace(i) == m.activeTab {
			renderedTabs = append(renderedTabs, activeTabStyle.Render(t))
		} else {
			renderedTabs = append(renderedTabs, inactiveTabStyle.Render(t))
		}
	}
	tabRow := lipgloss.JoinHorizontal(lipgloss.Top, renderedTabs...)

	sidebarWidth := 50
	if m.width < 110 {
		sidebarWidth = int(float64(m.width) * 0.35)
		if sidebarWidth < 30 {
			sidebarWidth = 30
		}
	}
	mainWidth := m.width - sidebarWidth - 1

	var content string
	switch m.activeTab {
	case LogsWorkspace:
		content = m.logsView.View()
	case ChatWorkspace:
		chatContent := lipgloss.JoinVertical(lipgloss.Center,
			theme.TitleStyle().Render("Neural Chat"),
			"",
			"Coming soon...",
		)
		content = lipgloss.Place(mainWidth, m.height-3, lipgloss.Center, lipgloss.Center, chatContent)
	case DebugWorkspace:
		content = m.debug.View()
	}

	mainCol := lipgloss.JoinVertical(lipgloss.Left,
		tabRow,
		content,
	)

	sidebarCol := m.sidebar.View()

	sidebarCol = lipgloss.NewStyle().Width(sidebarWidth).MaxWidth(sidebarWidth).Height(m.height - 1).MaxHeight(m.height - 1).Render(sidebarCol)
	mainCol = lipgloss.NewStyle().Width(mainWidth).MaxWidth(mainWidth).Height(m.height - 1).MaxHeight(m.height - 1).Render(mainCol)

	fullGrid := lipgloss.JoinHorizontal(lipgloss.Top, sidebarCol, mainCol)

	helpText := " TAB:Switch │ ALT+TAB:Rev │ ↑/↓:Scroll │ ENTER:Run │ F:Force │ P:Parallel │ A:Auto │ X:Abort │ CTRL+S:Snapshot │ Q:Quit "
	if m.confirmQuit {
		helpText = " Press ENTER again to confirm quit, or ESC to cancel "
	}
	helpBar := lipgloss.NewStyle().
		Background(theme.ActiveTheme.Bg).
		Foreground(theme.ActiveTheme.Primary).
		Bold(true).
		Width(m.width).
		Render(helpText)

	fullView := lipgloss.JoinVertical(lipgloss.Left, fullGrid, helpBar)

	return lipgloss.NewStyle().Width(m.width).Height(m.height).MaxWidth(m.width).MaxHeight(m.height).Render(fullView)
}
