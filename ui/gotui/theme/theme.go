package theme

import "github.com/charmbracelet/lipgloss"

type Theme struct {
	Primary   lipgloss.Color
	Secondary lipgloss.Color
	Success   lipgloss.Color
	Error     lipgloss.Color
	Warning   lipgloss.Color
	Text      lipgloss.Color
	Bg        lipgloss.Color
}

var Themes = map[string]Theme{
	"dracula": {
		Primary:   lipgloss.Color("#bd93f9"),
		Secondary: lipgloss.Color("#8be9fd"),
		Success:   lipgloss.Color("#50fa7b"),
		Error:     lipgloss.Color("#ff5555"),
		Warning:   lipgloss.Color("#f1fa8c"),
		Text:      lipgloss.Color("#f8f8f2"),
		Bg:        lipgloss.Color("#282a36"),
	},
	"catppuccin": {
		Primary:   lipgloss.Color("#cba6f7"),
		Secondary: lipgloss.Color("#89b4fa"),
		Success:   lipgloss.Color("#a6e3a1"),
		Error:     lipgloss.Color("#f38ba8"),
		Warning:   lipgloss.Color("#f9e2af"),
		Text:      lipgloss.Color("#cdd6f4"),
		Bg:        lipgloss.Color("#1e1e2e"),
	},
	"cyberpunk": {
		Primary:   lipgloss.Color("#00f0ff"),
		Secondary: lipgloss.Color("#ff003c"),
		Success:   lipgloss.Color("#00ff88"),
		Error:     lipgloss.Color("#ff004c"),
		Warning:   lipgloss.Color("#fcee0a"),
		Text:      lipgloss.Color("#d7f7ff"),
		Bg:        lipgloss.Color("#020304"),
	},
}

// Global active theme
var ActiveTheme = Themes["cyberpunk"]

// Reusable styles based on the active theme
func BaseStyle() lipgloss.Style {
	return lipgloss.NewStyle().Foreground(ActiveTheme.Text)
}

func TitleStyle() lipgloss.Style {
	return lipgloss.NewStyle().Foreground(ActiveTheme.Primary).Bold(true)
}

func BorderStyle() lipgloss.Style {
	return lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ActiveTheme.Primary)
}
