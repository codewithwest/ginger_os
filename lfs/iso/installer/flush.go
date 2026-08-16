package main

import (
	"fmt"
	"path/filepath"
	"syscall"
)

// flush syncs the filesystem and unmounts the target once. It is safe to call
// multiple times; only the first invocation does work.
func (d *deployer) flush() {
	if d.flushed {
		return
	}
	d.flushed = true
	dl.logf("FLUSH: syncing filesystem")
	fmt.Println("  [flush] Syncing filesystem...")
	syscall.Sync()
	syscall.Sync()
	for _, mp := range []string{"sys", "proc", "dev"} {
		syscall.Unmount(filepath.Join(d.mnt, mp), 0)
	}
	syscall.Unmount(d.mnt, 0)
	dl.logf("FLUSH: unmounted and synced")
	fmt.Println("  [flush] Unmounted and synced.")
}
