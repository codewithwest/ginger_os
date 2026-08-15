package main

import (
	"crypto/ed25519"
	"encoding/base64"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const usage = `ginger-pkg — GingerOS package manager

Usage:
  ginger-pkg keygen [--pub FILE] [--priv FILE]
  ginger-pkg bundle create --name N --version V --key PRIVKEY --dir PAYLOAD [-o OUT] [--service UNIT ...]
  ginger-pkg install BUNDLE
  ginger-pkg upgrade BUNDLE
  ginger-pkg remove NAME
  ginger-pkg list
  ginger-pkg verify NAME [VERSION]
  ginger-pkg status [NAME]
  ginger-pkg rollback NAME

Brain-side update server:
  ginger-pkg serve [--addr :8081] [--root /opt/ginger]

Node-side update agent:
  ginger-pkg update --server http://brain:8081 [--name PKG] [--once] [--interval 60]

Store root: %s
`

func die(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "error: "+format+"\n", args...)
	os.Exit(1)
}

func main() {
	args := os.Args[1:]
	if len(args) == 0 {
		fmt.Fprintf(os.Stderr, usage, RootDir)
		os.Exit(2)
	}
	var err error
	switch args[0] {
	case "keygen":
		err = cmdKeygen(args[1:])
	case "bundle":
		err = cmdBundle(args[1:])
	case "install":
		err = cmdInstall(args[1:])
	case "upgrade":
		err = cmdUpgrade(args[1:])
	case "remove":
		err = cmdRemove(args[1:])
	case "list":
		err = cmdList(args[1:])
	case "verify":
		err = cmdVerify(args[1:])
	case "status":
		err = cmdStatus(args[1:])
	case "rollback":
		err = cmdRollback(args[1:])
	case "serve":
		err = cmdServe(args[1:])
	case "update":
		err = cmdUpdate(args[1:])
	case "help", "-h", "--help":
		fmt.Fprintf(os.Stderr, usage, RootDir)
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n\n", args[0])
		fmt.Fprintf(os.Stderr, usage, RootDir)
		os.Exit(2)
	}
	if err != nil {
		die("%v", err)
	}
}

// --- keygen ---
func cmdKeygen(args []string) error {
	pub, priv := filepath.Join(RootDir, "keys", "signing.pub"),
		filepath.Join(RootDir, "keys", "signing.key")
	for i := 0; i+1 < len(args); i += 2 {
		switch args[i] {
		case "--pub":
			pub = args[i+1]
		case "--priv":
			priv = args[i+1]
		}
	}
	if err := os.MkdirAll(filepath.Dir(pub), 0o700); err != nil {
		return err
	}
	if err := generateKey(pub, priv); err != nil {
		return err
	}
	fmt.Printf("wrote signing key:   %s\nwrote public key:    %s\n", priv, pub)
	fmt.Println("keep the private key on the brain; distribute the public key to nodes")
	return nil
}

// --- bundle create ---
func cmdBundle(args []string) error {
	var name, version, keyPath, dir, out string
	var services []string
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--name":
			name = next(args, &i)
		case "--version":
			version = next(args, &i)
		case "--key":
			keyPath = next(args, &i)
		case "--dir":
			dir = next(args, &i)
		case "-o":
			out = next(args, &i)
		case "--service":
			services = append(services, next(args, &i))
		}
	}
	if name == "" || version == "" || keyPath == "" || dir == "" {
		return fmt.Errorf("bundle create needs --name --version --key --dir")
	}
	privB64, err := os.ReadFile(keyPath)
	if err != nil {
		return err
	}
	privDER, err := base64.StdEncoding.DecodeString(strings.TrimSpace(string(privB64)))
	if err != nil {
		return fmt.Errorf("bad private key: %w", err)
	}
	priv := ed25519.PrivateKey(privDER)
	m := &Manifest{Name: name, Version: version, Services: services}
	if out == "" {
		out = fmt.Sprintf("%s_%s%s", name, version, BundleExt)
	}
	if err := createBundle(dir, out, m, priv); err != nil {
		return err
	}
	signed := "UNSIGNED"
	if m.SigningKey != "" && m.Signature != "" {
		signed = "signed"
	}
	fmt.Printf("created %s (%d files, %s)\n", out, len(m.Files), signed)
	return nil
}

func next(args []string, i *int) string {
	*i++
	if *i >= len(args) {
		return ""
	}
	return args[*i]
}

// --- install/upgrade ---
func cmdInstall(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("install needs a bundle path")
	}
	return installBundle(args[0], false)
}

func cmdUpgrade(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("upgrade needs a bundle path")
	}
	return installBundle(args[0], true)
}

func installBundle(bundlePath string, isUpgrade bool) error {
	st, err := loadState()
	if err != nil {
		return err
	}
	trustedKey := os.Getenv("GINGER_TRUSTED_KEY")
	if trustedKey == "" {
		trustedKey = filepath.Join(RootDir, "keys", "signing.pub")
	}
	target := ""
	m, err := func() (*Manifest, error) {
		// Extract the verified bundle straight into <name>/<version>.
		var tmp string
		tmp, err = os.MkdirTemp("", "ginger-stage-*")
		if err != nil {
			return nil, err
		}
		defer os.RemoveAll(tmp)

		m, err := extractBundle(bundlePath, tmp)
		if err != nil {
			return nil, err
		}
		if err := m.checkTrustedKey(trustedKey); err != nil {
			return nil, err
		}
		target = versionDir(m.Name, m.Version)
		if err := os.RemoveAll(target); err != nil {
			return nil, err
		}
		if err := os.MkdirAll(target, 0o755); err != nil {
			return nil, err
		}
		// Move the staged payload + manifest into place.
		for _, part := range []string{manifestF, "files"} {
			src := filepath.Join(tmp, part)
			if _, serr := os.Stat(src); serr != nil {
				continue // "files" may not exist for empty payloads
			}
			if err := os.Rename(src, filepath.Join(target, part)); err != nil {
				return nil, err
			}
		}
		return m, nil
	}()
	if err != nil {
		return err
	}

	// Record state.
	entry, ok := st.Packages[m.Name]
	if !ok {
		entry = &InstalledEntry{Name: m.Name}
		st.Packages[m.Name] = entry
	}
	if !contains(entry.Versions, m.Version) {
		entry.Versions = append(entry.Versions, m.Version)
		sortVersionsDesc(entry.Versions)
	}
	entry.Services = m.Services
	entry.ActiveVersion = m.Version
	if err := saveState(st); err != nil {
		return err
	}

	// Activate.
	if err := os.MkdirAll(filepath.Join(RootDir, currentDir), 0o755); err != nil {
		return err
	}
	if err := activateAtomically(m.Name, m.Version); err != nil {
		return err
	}
	// Install unit files + start services.
	if err := installUnitFiles(target, m.Services); err != nil {
		return fmt.Errorf("unit install: %w", err)
	}
	if err := startServices(m.Services); err != nil {
		return fmt.Errorf("service start: %w", err)
	}

	verb := "installed"
	if isUpgrade {
		verb = "upgraded to"
	}
	fmt.Printf("%s %s %s → %s\n", m.Name, verb, prevOrActive(entry, m.Version), m.Version)
	return nil
}

func prevOrActive(e *InstalledEntry, ver string) string {
	for _, v := range e.Versions {
		if v != ver {
			return v
		}
	}
	return ""
}

// --- remove ---
func cmdRemove(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("remove needs a package name")
	}
	name := args[0]
	st, err := loadState()
	if err != nil {
		return err
	}
	entry, ok := st.Packages[name]
	if !ok {
		return fmt.Errorf("package %s is not installed", name)
	}
	if err := stopServices(entry.Services); err != nil {
		return err
	}
	os.RemoveAll(bundleDir(name))
	os.RemoveAll(currentLink(name))
	delete(st.Packages, name)
	if err := saveState(st); err != nil {
		return err
	}
	fmt.Printf("removed %s\n", name)
	return nil
}

// --- list ---
func cmdList(args []string) error {
	st, err := loadState()
	if err != nil {
		return err
	}
	if len(st.Packages) == 0 {
		fmt.Println("no packages installed")
		return nil
	}
	for _, entry := range st.Packages {
		fmt.Printf("%-24s active=%s  versions=%s\n", entry.Name, entry.ActiveVersion, strings.Join(entry.Versions, ", "))
	}
	return nil
}

// --- verify ---
func cmdVerify(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("verify needs a package name")
	}
	name := args[0]
	ver := ""
	if len(args) > 1 {
		ver = args[1]
	}
	if ver == "" {
		v, err := resolveCurrent(name)
		if err != nil {
			return fmt.Errorf("no active version for %s", name)
		}
		ver = v
	}
	if err := verifyBundle(name, ver); err != nil {
		return err
	}
	fmt.Printf("OK %s %s\n", name, ver)
	return nil
}

// --- status ---
func cmdStatus(args []string) error {
	st, err := loadState()
	if err != nil {
		return err
	}
	for _, entry := range st.Packages {
		if len(args) > 0 && entry.Name != args[0] {
			continue
		}
		ok := "OK"
		if err := verifyBundle(entry.Name, entry.ActiveVersion); err != nil {
			ok = "DEGRADED"
		}
		fmt.Printf("%s %-8s %-24s %s\n", ok, entry.ActiveVersion, entry.Name, strings.Join(entry.Services, ","))
	}
	return nil
}

// --- rollback ---
func cmdRollback(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("rollback needs a package name")
	}
	name := args[0]
	st, err := loadState()
	if err != nil {
		return err
	}
	entry, ok := st.Packages[name]
	if !ok {
		return fmt.Errorf("package %s is not installed", name)
	}
	prev := findPrev(name, entry.ActiveVersion)
	if prev == "" {
		return fmt.Errorf("no previous version to roll back to")
	}
	// Restart service units to pick up the swapped payload.
	if err := stopServices(entry.Services); err != nil {
		return err
	}
	if err := activateAtomically(name, prev); err != nil {
		return err
	}
	if err := installUnitFiles(versionDir(name, prev), entry.Services); err != nil {
		return err
	}
	if err := startServices(entry.Services); err != nil {
		return err
	}
	entry.ActiveVersion = prev
	if err := saveState(st); err != nil {
		return err
	}
	fmt.Printf("rolled back %s to %s\n", name, prev)
	return nil
}

// --- helpers ---
func contains(list []string, s string) bool {
	for _, v := range list {
		if v == s {
			return true
		}
	}
	return false
}

func sortVersionsDesc(list []string) {
	for i := 1; i < len(list); i++ {
		for j := i; j > 0 && compareVersions(list[j-1], list[j]) < 0; j-- {
			list[j-1], list[j] = list[j], list[j-1]
		}
	}
}
