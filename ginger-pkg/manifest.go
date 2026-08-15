package main

import (
	"bytes"
	"crypto/ed25519"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// FileEntry describes a single file inside the bundle payload.
type FileEntry struct {
	Path   string `json:"path"`   // path relative to bundle root (e.g. "usr/bin/ginger-room-node")
	Mode   uint32 `json:"mode"`   // unix permission bits
	SHA256 string `json:"sha256"` // hex digest of the file content
}

// Manifest is the signed description of a bundle.
type Manifest struct {
	Name       string      `json:"name"`
	Version    string      `json:"version"`
	Depends    []string    `json:"deps,omitempty"`
	Files      []FileEntry `json:"files"`
	Services   []string    `json:"services,omitempty"` // systemd unit basenames to enable
	Signature  string      `json:"signature"`          // ed25519 sig over the canonical manifest (excluding this field)
	SigningKey string      `json:"signing_key"`        // base64 DER of the ed25519 public key
}

// canonical returns the manifest JSON exactly as it will be signed: without
// the Signature field, fields in declaration order, no trailing newline.
func (m *Manifest) canonical() ([]byte, error) {
	cp := *m
	cp.Signature = ""
	cp.SigningKey = ""
	return json.Marshal(&cp)
}

// Sign signs the canonical manifest with the given ed25519 private key.
func (m *Manifest) Sign(priv ed25519.PrivateKey) error {
	canon, err := m.canonical()
	if err != nil {
		return err
	}
	pubDER, err := x509.MarshalPKIXPublicKey(priv.Public())
	if err != nil {
		return err
	}
	m.SigningKey = base64.StdEncoding.EncodeToString(pubDER)
	m.Signature = base64.StdEncoding.EncodeToString(ed25519.Sign(priv, canon))
	return nil
}

// Verify checks the signature against the public key embedded in the manifest.
func (m *Manifest) Verify() error {
	if m.Signature == "" || m.SigningKey == "" {
		return errors.New("manifest has no signature")
	}
	canon, err := m.canonical()
	if err != nil {
		return err
	}
	pubDER, err := base64.StdEncoding.DecodeString(m.SigningKey)
	if err != nil {
		return fmt.Errorf("bad signing key encoding: %w", err)
	}
	pubAny, err := x509.ParsePKIXPublicKey(pubDER)
	if err != nil {
		return fmt.Errorf("bad signing key: %w", err)
	}
	pub, ok := pubAny.(ed25519.PublicKey)
	if !ok {
		return errors.New("signing key is not ed25519")
	}
	sig, err := base64.StdEncoding.DecodeString(m.Signature)
	if err != nil {
		return fmt.Errorf("bad signature encoding: %w", err)
	}
	if !ed25519.Verify(pub, canon, sig) {
		return errors.New("manifest signature is invalid")
	}
	return nil
}

// checkTrustedKey verifies the manifest was signed by a trusted public key.
// trustedPath may be a base64-encoded ed25519 public key file, or "" to skip.
func (m *Manifest) checkTrustedKey(trustedPath string) error {
	if trustedPath == "" {
		return nil // no trusted key configured — skip enforcement
	}
	trustedB64, err := os.ReadFile(trustedPath)
	if err != nil {
		return fmt.Errorf("reading trusted key: %w", err)
	}
	trusted, err := base64.StdEncoding.DecodeString(strings.TrimSpace(string(trustedB64)))
	if err != nil {
		return fmt.Errorf("bad trusted key: %w", err)
	}
	sigKey, err := base64.StdEncoding.DecodeString(m.SigningKey)
	if err != nil {
		return fmt.Errorf("bad manifest key: %w", err)
	}
	if !bytes.Equal(trusted, sigKey) {
		return errors.New("bundle signed by untrusted key — refusing to install")
	}
	return nil
}

// loadManifest reads and parses a manifest.json.
func loadManifest(path string) (*Manifest, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var m Manifest
	if err := json.Unmarshal(b, &m); err != nil {
		return nil, fmt.Errorf("parsing manifest %s: %w", path, err)
	}
	return &m, nil
}

// fileSHA256 returns the hex sha256 of a file.
func fileSHA256(path string) (string, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	h := sha256.Sum256(b)
	return fmt.Sprintf("%x", h), nil
}

// writeManifest writes the manifest to path and returns the bytes written.
func writeManifest(path string, m *Manifest) ([]byte, error) {
	b, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return nil, err
	}
	b = append(b, '\n')
	return b, os.WriteFile(path, b, 0o644)
}

// installUnitFiles copies any *.service units from the bundle payload into the
// host systemd unit dir and runs daemon-reload. Missing host dir is tolerated
// (non-Linux/dev smoke tests).
func installUnitFiles(bundleRoot string, services []string) error {
	unitDir := "/etc/systemd/system"
	if _, err := os.Stat(unitDir); err != nil {
		return nil // not a systemd host (e.g. dev smoke test)
	}
	needReload := false
	for _, unit := range services {
		name := filepath.Base(unit)
		src := filepath.Join(bundleRoot, "files", "etc", "systemd", "system", name)
		b, err := os.ReadFile(src)
		if err != nil {
			continue // unit file not bundled; rely on existing one
		}
		dst := filepath.Join(unitDir, name)
		if err := os.WriteFile(dst, b, 0o644); err != nil {
			return err
		}
		needReload = true
	}
	if needReload {
		return runCmd("systemctl", "daemon-reload")
	}
	return nil
}
