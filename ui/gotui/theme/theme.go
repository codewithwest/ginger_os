package theme

import "github.com/charmbracelet/lipgloss"

type Theme struct {
	Primary   lipgloss.Color
	Secondary lipgloss.Color
	Success   lipgloss.Color
	Error     lipgloss.Color
	Warning   lipgloss.Color
	Text      lipgloss.Color
	TextDim   lipgloss.Color
	Bg        lipgloss.Color
	BgAlt     lipgloss.Color
	Border    lipgloss.Color
}

var Themes = map[string]Theme{
	"dracula": {
		Primary:   lipgloss.Color("#bd93f9"),
		Secondary: lipgloss.Color("#8be9fd"),
		Success:   lipgloss.Color("#50fa7b"),
		Error:     lipgloss.Color("#ff5555"),
		Warning:   lipgloss.Color("#f1fa8c"),
		Text:      lipgloss.Color("#f8f8f2"),
		TextDim:   lipgloss.Color("#6272a4"),
		Bg:        lipgloss.Color("#282a36"),
		BgAlt:     lipgloss.Color("#21222c"),
		Border:    lipgloss.Color("#44475a"),
	},
	"catppuccin": {
		Primary:   lipgloss.Color("#cba6f7"),
		Secondary: lipgloss.Color("#89b4fa"),
		Success:   lipgloss.Color("#a6e3a1"),
		Error:     lipgloss.Color("#f38ba8"),
		Warning:   lipgloss.Color("#f9e2af"),
		Text:      lipgloss.Color("#cdd6f4"),
		TextDim:   lipgloss.Color("#6c7086"),
		Bg:        lipgloss.Color("#1e1e2e"),
		BgAlt:     lipgloss.Color("#181825"),
		Border:    lipgloss.Color("#313244"),
	},
	"cyberpunk": {
		Primary:   lipgloss.Color("#00f0ff"),
		Secondary: lipgloss.Color("#ff003c"),
		Success:   lipgloss.Color("#00ff88"),
		Error:     lipgloss.Color("#ff004c"),
		Warning:   lipgloss.Color("#fcee0a"),
		Text:      lipgloss.Color("#d7f7ff"),
		TextDim:   lipgloss.Color("#4a6b7a"),
		Bg:        lipgloss.Color("#020304"),
		BgAlt:     lipgloss.Color("#0a0e12"),
		Border:    lipgloss.Color("#1a2a3a"),
	},
	"nord": {
		Primary:   lipgloss.Color("#88c0d0"),
		Secondary: lipgloss.Color("#b48ead"),
		Success:   lipgloss.Color("#a3be8c"),
		Error:     lipgloss.Color("#bf616a"),
		Warning:   lipgloss.Color("#ebcb8b"),
		Text:      lipgloss.Color("#e5e9f0"),
		TextDim:   lipgloss.Color("#616e88"),
		Bg:        lipgloss.Color("#2e3440"),
		BgAlt:     lipgloss.Color("#252b38"),
		Border:    lipgloss.Color("#434c5e"),
	},
}

var ActiveTheme = Themes["cyberpunk"]

var (
	baseStyle   lipgloss.Style
	titleStyle  lipgloss.Style
	borderStyle lipgloss.Style
	dimStyle    lipgloss.Style
)

func init() {
	rebuildStyles()
}

func rebuildStyles() {
	baseStyle = lipgloss.NewStyle().Foreground(ActiveTheme.Text)
	titleStyle = lipgloss.NewStyle().Foreground(ActiveTheme.Primary).Bold(true).MarginBottom(1)
	borderStyle = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ActiveTheme.Border).Padding(0, 1)
	dimStyle = lipgloss.NewStyle().Foreground(ActiveTheme.TextDim)
}

func SetTheme(name string) {
	if t, ok := Themes[name]; ok {
		ActiveTheme = t
		rebuildStyles()
	}
}

func BaseStyle() lipgloss.Style       { return baseStyle }
func TitleStyle() lipgloss.Style       { return titleStyle }
func BorderStyle() lipgloss.Style      { return borderStyle }
func DimStyle() lipgloss.Style         { return dimStyle }
