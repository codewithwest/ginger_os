package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"golang.org/x/term"
)

const (
	colorReset  = "\033[0m"
	colorBold   = "\033[1m"
	colorDim    = "\033[2m"
	colorGreen  = "\033[32m"
	colorCyan   = "\033[36m"
	colorYellow = "\033[33m"
	colorRed    = "\033[31m"
	clearScreen = "\033[H\033[J"
)

func printf(color, format string, args ...any) {
	fmt.Print(color)
	fmt.Printf(format, args...)
	fmt.Print(colorReset)
}

func printfln(color, format string, args ...any) {
	printf(color, format+"\n", args...)
}

func stripANSI(s string) string {
	var b strings.Builder
	inEsc := false
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == 0x1b {
			inEsc = true
			continue
		}
		if inEsc {
			if c == 'm' {
				inEsc = false
			}
			continue
		}
		b.WriteByte(c)
	}
	return b.String()
}

func rlen(s string) int { return utf8.RuneCountInString(stripANSI(s)) }

func padTo(s string, n int) string {
	if rlen(s) >= n {
		return s
	}
	return s + strings.Repeat(" ", n-rlen(s))
}

func frame(title string, content []string) {
	inner := 44
	for _, l := range content {
		if n := rlen(l); n > inner {
			inner = n
		}
	}
	w := inner + 6

	fmt.Print(colorCyan + colorBold)
	if title != "" {
		t := "─ " + title + " ─"
		pad := w - 4 - rlen(t)
		left := pad / 2
		right := pad - left
		fmt.Printf("  ╭%s%s%s╮\n", strings.Repeat("─", left), t, strings.Repeat("─", right))
	} else {
		fmt.Printf("  ╭%s╮\n", strings.Repeat("─", w-4))
	}
	fmt.Print(colorReset)

	for _, l := range content {
		fmt.Printf("  ║ %s ║\n", padTo(l, inner))
	}

	fmt.Print(colorCyan + colorBold)
	fmt.Printf("  ╰%s╯\n", strings.Repeat("─", w-4))
	fmt.Print(colorReset)
}

func elapsed(start time.Time) string {
	d := time.Since(start)
	if d < time.Second {
		return ""
	}
	return d.Round(time.Second).String()
}

func humanSize(b int64) string {
	units := []string{"B", "KiB", "MiB", "GiB", "TiB"}
	f := float64(b)
	u := 0
	for f >= 1024 && u < len(units)-1 {
		f /= 1024
		u++
	}
	if u == 0 {
		return fmt.Sprintf("%d B", b)
	}
	return fmt.Sprintf("%.1f %s", f, units[u])
}

func progressBar(pct float64, w int) string {
	fill := int(pct * float64(w) / 100)
	if fill < 0 {
		fill = 0
	}
	if fill > w {
		fill = w
	}
	return colorGreen + strings.Repeat("█", fill) + colorDim + strings.Repeat("░", w-fill) + colorReset
}

func gzipUncompressedSize(path string) int64 {
	out, err := exec.Command("gzip", "-l", path).Output()
	if err != nil {
		return 0
	}
	for _, ln := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		f := strings.Fields(ln)
		if len(f) >= 2 && f[0] != "compressed" && f[0] != "total" {
			if n, err := strconv.ParseInt(f[1], 10, 64); err == nil {
				return n
			}
		}
	}
	return 0
}

func dirSize(dir string) int64 {
	out, err := exec.Command("du", "-sb", dir).Output()
	if err != nil {
		return 0
	}
	f := strings.Fields(string(out))
	if len(f) == 0 {
		return 0
	}
	n, _ := strconv.ParseInt(f[0], 10, 64)
	return n
}

func readLine() string {
	r := bufio.NewReader(os.Stdin)
	s, _ := r.ReadString('\n')
	return strings.TrimRight(s, "\r\n")
}

func readPassword() string {
	fd := int(os.Stdin.Fd())
	pw, _ := term.ReadPassword(fd)
	fmt.Println()
	return strings.TrimRight(string(pw), "\r\n")
}

func writeFileSync(path string, data []byte, perm os.FileMode) error {
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, perm)
	if err != nil {
		return err
	}
	defer f.Close()
	if _, err := f.Write(data); err != nil {
		return err
	}
	return f.Sync()
}

func pause() {
	fmt.Print(colorDim + "Press [ENTER] to continue..." + colorReset)
	readLine()
}
