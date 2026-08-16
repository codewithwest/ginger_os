package main

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
)

// execRun runs a command, streaming a short description via update and
// returning a wrapped error with the captured output on failure.
func (d *deployer) execRun(update func(string), desc, cmd string, args ...string) error {
	update(desc)
	dl.logf("cmd: %s %s", cmd, strings.Join(args, " "))
	c := exec.Command(cmd, args...)
	var buf bytes.Buffer
	c.Stdout = &buf
	c.Stderr = &buf
	if err := c.Run(); err != nil {
		msg := strings.TrimSpace(buf.String())
		if msg != "" {
			dl.logf("FAIL %s: %v (%s)", desc, err, msg)
			return fmt.Errorf("%s: %v (%s)", desc, err, msg)
		}
		dl.logf("FAIL %s: %v", desc, err)
		return fmt.Errorf("%s: %v", desc, err)
	}
	dl.logf("OK   %s", desc)
	return nil
}
