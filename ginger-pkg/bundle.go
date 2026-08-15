package main

import (
	"archive/tar"
	"compress/gzip"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

const (
	BundleExt    = ".gingerbundle"
	ManifestName = "manifest.json"
	FilesPrefix  = "files/"
)

// createBundle packs a payload directory into a signed tarball.
// The manifest is signed twice: once pre-flight (to catch key errors early)
// and once more after the file list is finalized, immediately before writing.
func createBundle(payloadDir, outPath string, m *Manifest, key ed25519.PrivateKey) error {
	// Phase 1: walk the payload and build the finalized file list.
	root := filepath.Clean(payloadDir)
	m.Files = nil
	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		rel, rerr := filepath.Rel(root, path)
		if rerr != nil {
			return rerr
		}
		if rel == "." || info.IsDir() {
			return nil
		}
		sum, rerr := fileSHA256(path)
		if rerr != nil {
			return rerr
		}
		m.Files = append(m.Files, FileEntry{
			Path:   filepath.ToSlash(rel),
			Mode:   uint32(info.Mode().Perm()),
			SHA256: sum,
		})
		return nil
	})
	if err != nil {
		return err
	}
	if len(m.Files) == 0 {
		return errors.New("payload directory is empty")
	}

	// Phase 2: sign the finalized manifest.
	if err := m.Sign(key); err != nil {
		return err
	}
	full, err := json.Marshal(m) // full manifest INCLUDING signature + signing key
	if err != nil {
		return err
	}

	// Phase 3: single-pass tarball write.
	out, err := os.Create(outPath)
	if err != nil {
		return err
	}
	defer out.Close()
	gz := gzip.NewWriter(out)
	defer gz.Close()
	tw := tar.NewWriter(gz)
	defer tw.Close()

	// Manifest first (includes final signature + file list).
	if err := tw.WriteHeader(&tar.Header{
		Name: ManifestName, Mode: 0o644, Size: int64(len(full)),
	}); err != nil {
		return err
	}
	if _, err := tw.Write(full); err != nil {
		return err
	}

	// Payload files.
	for _, fe := range m.Files {
		abs := filepath.Join(root, filepath.FromSlash(fe.Path))
		content, rerr := os.ReadFile(abs)
		if rerr != nil {
			return rerr
		}
		name := FilesPrefix + fe.Path
		if err := tw.WriteHeader(&tar.Header{
			Name: name, Mode: int64(fe.Mode), Size: int64(len(content)),
		}); err != nil {
			return err
		}
		if _, err := tw.Write(content); err != nil {
			return err
		}
	}
	return nil
}

// extractBundle streams a bundle tarball into destDir, verifying the manifest
// signature and every file checksum. On any failure the partial tree is removed.
func extractBundle(bundlePath, destDir string) (*Manifest, error) {
	f, err := os.Open(bundlePath)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	gz, err := gzip.NewReader(f)
	if err != nil {
		return nil, fmt.Errorf("bad gzip: %w", err)
	}
	defer gz.Close()
	tr := tar.NewReader(gz)

	// Manifest entry must come first.
	hdr, err := tr.Next()
	if err != nil {
		return nil, errors.New("bundle is empty")
	}
	if hdr.Name != ManifestName {
		return nil, errors.New("bundle does not start with manifest.json")
	}
	manBytes, err := io.ReadAll(tr)
	if err != nil {
		return nil, err
	}
	var m Manifest
	if err := json.Unmarshal(manBytes, &m); err != nil {
		return nil, fmt.Errorf("bad manifest: %w", err)
	}
	if err := m.Verify(); err != nil {
		return nil, err
	}

	// Stage into destDir.
	if err := os.RemoveAll(destDir); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(destDir, 0o755); err != nil {
		return nil, err
	}
	defer func() {
		if err != nil {
			os.RemoveAll(destDir)
		}
	}()

	files := make(map[string]FileEntry, len(m.Files))
	for _, fe := range m.Files {
		files[fe.Path] = fe
	}

	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		if !strings.HasPrefix(hdr.Name, FilesPrefix) {
			continue
		}
		rel := strings.TrimPrefix(hdr.Name, FilesPrefix)
		fe, ok := files[rel]
		if !ok {
			return nil, fmt.Errorf("bundle contains file not in manifest: %s", rel)
		}
		// Mirror the bundle layout: payload lives under files/ in the store too.
		abs := filepath.Join(destDir, "files", filepath.FromSlash(rel))
		if err := os.MkdirAll(filepath.Dir(abs), 0o755); err != nil {
			return nil, err
		}
		content, err := io.ReadAll(tr)
		if err != nil {
			return nil, err
		}
		sum := sha256Hex(content)
		if sum != fe.SHA256 {
			return nil, fmt.Errorf("checksum mismatch for %s", rel)
		}
		if err := os.WriteFile(abs, content, os.FileMode(fe.Mode)); err != nil {
			return nil, err
		}
	}

	// Every manifest file must have been extracted.
	if len(files) != len(m.Files) {
		return nil, errors.New("manifest file list not fully present in bundle")
	}

	// Persist the verified manifest alongside the payload.
	if _, err := writeManifest(filepath.Join(destDir, ManifestName), &m); err != nil {
		return nil, err
	}
	return &m, nil
}

func sha256Hex(b []byte) string {
	return fmt.Sprintf("%x", sha256Sum(b))
}

// generateKey creates a new ed25519 keypair, writing PKCS8 DER (base64) files.
func generateKey(pubPath, privPath string) error {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return err
	}
	// Write the public key in PKIX DER form so it matches what bundles embed
	// in manifest.signing_key (byte-for-byte comparable for trust checks).
	pubDER, err := x509.MarshalPKIXPublicKey(pub)
	if err != nil {
		return err
	}
	pubB64 := base64.StdEncoding.EncodeToString(pubDER)
	privB64 := base64.StdEncoding.EncodeToString(priv)
	if err := os.WriteFile(pubPath, []byte(pubB64+"\n"), 0o644); err != nil {
		return err
	}
	if err := os.WriteFile(privPath, []byte(privB64+"\n"), 0o600); err != nil {
		return err
	}
	return nil
}
