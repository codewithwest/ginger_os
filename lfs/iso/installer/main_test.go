package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestEnsureResolverSymlink(t *testing.T) {
	tests := []struct {
		name       string
		setup      func(t *testing.T, path string)
		wantTarget string
	}{
		{
			name: "creates when missing",
		},
		{
			name: "replaces regular resolver file",
			setup: func(t *testing.T, path string) {
				t.Helper()
				if err := os.WriteFile(path, []byte("nameserver 8.8.8.8\n"), 0644); err != nil {
					t.Fatal(err)
				}
			},
		},
		{
			name: "replaces wrong symlink",
			setup: func(t *testing.T, path string) {
				t.Helper()
				if err := os.Symlink("/etc/hosts", path); err != nil {
					t.Fatal(err)
				}
			},
		},
		{
			name: "preserves correct dangling runtime symlink",
			setup: func(t *testing.T, path string) {
				t.Helper()
				if err := os.Symlink(resolverStubTarget, path); err != nil {
					t.Fatal(err)
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			root := t.TempDir()
			etc := filepath.Join(root, "etc")
			if err := os.MkdirAll(etc, 0755); err != nil {
				t.Fatal(err)
			}
			path := filepath.Join(etc, "resolv.conf")
			if tt.setup != nil {
				tt.setup(t, path)
			}

			if err := ensureResolverSymlink(root); err != nil {
				t.Fatalf("ensureResolverSymlink() error = %v", err)
			}
			got, err := os.Readlink(path)
			if err != nil {
				t.Fatalf("Readlink(%q) error = %v", path, err)
			}
			if got != resolverStubTarget {
				t.Fatalf("resolver symlink = %q, want %q", got, resolverStubTarget)
			}
			if _, err := os.Stat(filepath.Join(root, "run/systemd/resolve/stub-resolv.conf")); !os.IsNotExist(err) {
				t.Fatalf("test expects runtime stub to be absent, Stat error = %v", err)
			}
		})
	}
}
