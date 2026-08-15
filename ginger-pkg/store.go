package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

// RootDir is the base of the ginger package store.
var RootDir = "/opt/ginger"

func init() {
	if v := os.Getenv("GINGER_ROOT"); v != "" {
		RootDir = v
	}
}

const (
	bundlesDir = "bundles"
	currentDir = "current"
	stateFile  = "state.json"
	manifestF  = "manifest.json"
)

// InstalledEntry records the active version of one package.
type InstalledEntry struct {
	Name          string   `json:"name"`
	ActiveVersion string   `json:"active_version"`
	Versions      []string `json:"versions"` // installed, newest first
	Services      []string `json:"services,omitempty"`
}

// State is the whole /opt/ginger/state.json.
type State struct {
	Packages map[string]*InstalledEntry `json:"packages"`
}

func loadState() (*State, error) {
	s := &State{Packages: map[string]*InstalledEntry{}}
	b, err := os.ReadFile(filepath.Join(RootDir, stateFile))
	if err != nil {
		if os.IsNotExist(err) {
			return s, nil
		}
		return nil, err
	}
	if err := json.Unmarshal(b, s); err != nil {
		return nil, err
	}
	if s.Packages == nil {
		s.Packages = map[string]*InstalledEntry{}
	}
	return s, nil
}

func saveState(s *State) error {
	b, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	b = append(b, '\n')
	return os.WriteFile(filepath.Join(RootDir, stateFile), b, 0o644)
}

func bundleDir(name string) string       { return filepath.Join(RootDir, bundlesDir, name) }
func versionDir(name, ver string) string { return filepath.Join(bundleDir(name), ver) }
func currentLink(name string) string     { return filepath.Join(RootDir, currentDir, name) }

// symlinkTarget computes the relative target for the current symlink so the
// link stays valid even if RootDir is moved.
func symlinkTarget(name, ver string) string {
	from := currentLink(name)
	to := versionDir(name, ver)
	rel, err := filepath.Rel(filepath.Dir(from), to)
	if err != nil {
		return to
	}
	return rel
}

// activateAtomically flips the current symlink to the new version.
func activateAtomically(name, ver string) error {
	link := currentLink(name)
	old := link + ".old"
	os.Remove(old)
	// Point a temp symlink at the new version, then rename over current.
	tmp := link + ".tmp"
	os.Remove(tmp)
	if err := os.Symlink(symlinkTarget(name, ver), tmp); err != nil {
		return err
	}
	return os.Rename(tmp, link)
}

// resolveCurrent returns the version that the current symlink points at.
func resolveCurrent(name string) (string, error) {
	link := currentLink(name)
	target, err := os.Readlink(link)
	if err != nil {
		return "", err
	}
	return filepath.Base(target), nil
}

func sha256Sum(b []byte) [32]byte { return sha256.Sum256(b) }

func runCmd(cmd string, args ...string) error {
	c := exec.Command(cmd, args...)
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	return c.Run()
}

// startServices enables + starts the given systemd units (tolerates non-systemd hosts).
func startServices(services []string) error {
	if _, err := os.Stat("/run/systemd/system"); err != nil {
		return nil
	}
	if len(services) == 0 {
		return nil
	}
	_ = runCmd("systemctl", append([]string{"daemon-reload"}, "")...) // no-op guard
	if err := runCmd("systemctl", append([]string{"enable", "--now"}, services...)...); err != nil {
		return err
	}
	return nil
}

// stopServices stops + disables units.
func stopServices(services []string) error {
	if _, err := os.Stat("/run/systemd/system"); err != nil {
		return nil
	}
	if len(services) == 0 {
		return nil
	}
	rev := make([]string, len(services))
	for i := range services {
		rev[len(services)-1-i] = services[i]
	}
	return runCmd("systemctl", append([]string{"disable", "--now"}, rev...)...)
}

// listVersions returns installed versions for a package, newest first.
func listVersions(name string) []string {
	dir := bundleDir(name)
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var vers []string
	for _, e := range entries {
		if e.IsDir() {
			vers = append(vers, e.Name())
		}
	}
	sort.Sort(sort.Reverse(sort.StringSlice(vers)))
	return vers
}

// findPrev returns the highest installed version strictly below ver (numeric).
func findPrev(name, ver string) string {
	for _, v := range listVersions(name) {
		if compareVersions(v, ver) < 0 {
			return v
		}
	}
	return ""
}

// verifyBundle checks every file's checksum in the active version.
func verifyBundle(name, ver string) error {
	dir := versionDir(name, ver)
	m, err := loadManifest(filepath.Join(dir, manifestF))
	if err != nil {
		return err
	}
	var bad []string
	for _, fe := range m.Files {
		abs := filepath.Join(dir, "files", filepath.FromSlash(fe.Path))
		sum, err := fileSHA256(abs)
		if err != nil {
			bad = append(bad, fe.Path+" (unreadable)")
			continue
		}
		if sum != fe.SHA256 {
			bad = append(bad, fe.Path+" (checksum mismatch)")
		}
	}
	if len(bad) > 0 {
		return fmt.Errorf("verify failed:\n  %s", strings.Join(bad, "\n  "))
	}
	return nil
}
