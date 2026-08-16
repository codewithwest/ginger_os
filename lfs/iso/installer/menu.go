package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"golang.org/x/term"
)

// readMenuKey reads a single keypress in raw mode. Returns "up", "down",
// "enter", "esc", or a single-character string for plain keys.
func readMenuKey() (string, error) {
	var b [8]byte
	n, err := os.Stdin.Read(b[:])
	if err != nil {
		return "", err
	}
	if n == 0 {
		return "", nil
	}
	c := b[0]
	switch {
	case c == 0x1b:
		if n >= 3 && b[1] == '[' {
			switch b[2] {
			case 'A':
				return "up", nil
			case 'B':
				return "down", nil
			case 'C':
				return "right", nil
			case 'D':
				return "left", nil
			}
		}
		return "esc", nil
	case c == '\r' || c == '\n':
		return "enter", nil
	case c == 0x7f:
		return "backspace", nil
	default:
		return string(c), nil
	}
}

// selectMenu renders an interactive arrow-key menu and returns the selected
// index (0-based). Returns -1 if the user cancelled (q / Esc). Falls back to
// a numbered prompt when stdin is not a terminal.
func selectMenu(title string, items []string) int {
	fd := int(os.Stdin.Fd())
	if !term.IsTerminal(fd) {
		content := []string{"  " + colorDim + "Select an option:" + colorReset, ""}
		for i, it := range items {
			content = append(content, fmt.Sprintf("  %s[%d]%s  %s", colorYellow+colorBold, i+1, colorReset, it))
		}
		content = append(content, "")
		frame(title, content)
		fmt.Println()
		printf(colorYellow+colorBold, "  Enter choice [1-%d]: ", len(items))
		input := readLine()
		idx, err := strconv.Atoi(strings.TrimSpace(input))
		if err == nil && idx >= 1 && idx <= len(items) {
			return idx - 1
		}
		return -1
	}

	old, err := term.MakeRaw(fd)
	if err != nil {
		return -1
	}
	defer term.Restore(fd, old)

	sel := 0
	for {
		fmt.Print(clearScreen)
		content := []string{}
		for i, it := range items {
			if i == sel {
				content = append(content, "  "+colorCyan+colorBold+"▶ "+colorReset+colorYellow+colorBold+it+colorReset)
			} else {
				content = append(content, "  "+colorDim+"  "+colorReset+it)
			}
		}
		content = append(content, "")
		content = append(content, "  "+colorDim+"↑/↓ navigate  ·  Enter select  ·  q quit"+colorReset)
		frame(title, content)
		fmt.Println()

		key, err := readMenuKey()
		if err != nil {
			return sel
		}
		switch key {
		case "up":
			sel = (sel - 1 + len(items)) % len(items)
		case "down":
			sel = (sel + 1) % len(items)
		case "enter":
			return sel
		case "q", "esc":
			return -1
		}
	}
}

// confirmPrompt renders an interactive Yes/No prompt and returns true for yes.
func confirmPrompt(title string, detail []string) bool {
	items := []string{"Yes", "No"}
	_ = detail
	choice := selectMenu(title, items)
	return choice == 0
}
