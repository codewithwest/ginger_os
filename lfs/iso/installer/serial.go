package main

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// serialConsole mirrors the debug log to /dev/ttyS0 so the serial capture
// keeps command-level diagnostics even though /dev/console is the VGA tty0.
// stderr is also redirected to the serial console so Go panics land there.
var serialConsole *os.File

func initSerialMirror() {
	f, err := os.OpenFile("/dev/ttyS0", os.O_WRONLY, 0)
	if err != nil {
		return
	}
	serialConsole = f
	os.Stderr = f
}

type debugLogger struct {
	mu        sync.Mutex
	ramPath   string
	diskPath  string
	diskReady bool
	serial    bool
}

var dl = &debugLogger{
	ramPath:  "/tmp/ginger-install.log",
	diskPath: "/mnt/ginger/var/log/ginger-install.log",
	serial:   true,
}

func (l *debugLogger) append(path, line string) {
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return
	}
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0644)
	if err != nil {
		return
	}
	defer f.Close()
	f.WriteString(line + "\n")
	if path == l.diskPath {
		f.Sync()
	}
}

func (l *debugLogger) logf(format string, args ...any) {
	l.mu.Lock()
	defer l.mu.Unlock()
	line := time.Now().Format("2006-01-02 15:04:05") + "  " + fmt.Sprintf(format, args...)
	l.append(l.ramPath, line)
	if l.diskReady {
		l.append(l.diskPath, line)
	}
	if serialConsole != nil && l.serial {
		fmt.Fprintf(serialConsole, "DBG %s\n", line)
	}
}
