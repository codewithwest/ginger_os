package main

import (
	"archive/tar"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// serverPackage is the JSON descriptor of one installable package version.
type serverPackage struct {
	Name     string   `json:"name"`
	Version  string   `json:"version"`
	Services []string `json:"services,omitempty"`
	Files    []string `json:"files,omitempty"`
}

// handleServe runs the brain-side update server.
// Usage: ginger-pkg serve [--addr :8081] [--root /opt/ginger]
func cmdServe(args []string) error {
	addr := ":8081"
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--addr":
			addr = next(args, &i)
		case "--root":
			RootDir = next(args, &i)
		}
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/v1/packages":
			servePackages(w, r)
		case strings.HasPrefix(r.URL.Path, "/v1/bundle/"):
			serveBundle(w, r)
		case r.URL.Path == "/healthz":
			w.Header().Set("Content-Type", "application/json")
			fmt.Fprint(w, `{"ok":true}`)
		default:
			http.NotFound(w, r)
		}
	})

	fmt.Printf("ginger-update-server listening on %s (root %s)\n", addr, RootDir)
	return http.ListenAndServe(addr, mux)
}

// servePackages lists every package and its available versions.
func servePackages(w http.ResponseWriter, r *http.Request) {
	pkgs, err := listServerPackages()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(pkgs)
}

func listServerPackages() (map[string][]serverPackage, error) {
	base := filepath.Join(RootDir, bundlesDir)
	dirs, err := os.ReadDir(base)
	if err != nil {
		return nil, err
	}
	out := map[string][]serverPackage{}
	for _, d := range dirs {
		if !d.IsDir() {
			continue
		}
		name := d.Name()
		vers, _ := os.ReadDir(filepath.Join(base, name))
		for _, v := range vers {
			if !v.IsDir() {
				continue
			}
			p := serverPackage{Name: name, Version: v.Name()}
			if m, err := loadManifest(filepath.Join(base, name, v.Name(), manifestF)); err == nil {
				p.Services = m.Services
				for _, f := range m.Files {
					p.Files = append(p.Files, f.Path)
				}
			}
			out[name] = append(out[name], p)
		}
		sort.Slice(out[name], func(i, j int) bool {
			return compareVersions(out[name][i].Version, out[name][j].Version) > 0
		})
	}
	return out, nil
}

// serveBundle streams a bundle tarball for <name>/<version>.
// URL: /v1/bundle/<name>/<version>
func serveBundle(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/bundle/"), "/")
	if len(parts) != 2 {
		http.Error(w, "expected /v1/bundle/<name>/<version>", http.StatusBadRequest)
		return
	}
	name, version := parts[0], parts[1]
	dir := versionDir(name, version)
	m, err := loadManifest(filepath.Join(dir, manifestF))
	if err != nil {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/gzip")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%s_%s%s", name, version, BundleExt))
	gz := gzip.NewWriter(w)
	defer gz.Close()
	tw := tar.NewWriter(gz)
	defer tw.Close()

	// Signed manifest first (the exact stored bytes, signature included).
	manPath := filepath.Join(dir, manifestF)
	manBytes, err := os.ReadFile(manPath)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if err := tw.WriteHeader(&tar.Header{Name: ManifestName, Mode: 0o644, Size: int64(len(manBytes))}); err != nil {
		return
	}
	if _, err := tw.Write(manBytes); err != nil {
		return
	}

	// Payload files.
	for _, fe := range m.Files {
		abs := filepath.Join(dir, "files", filepath.FromSlash(fe.Path))
		content, err := os.ReadFile(abs)
		if err != nil {
			http.Error(w, fmt.Sprintf("missing payload file %s", fe.Path), http.StatusInternalServerError)
			return
		}
		name := FilesPrefix + fe.Path
		if err := tw.WriteHeader(&tar.Header{Name: name, Mode: int64(fe.Mode), Size: int64(len(content))}); err != nil {
			return
		}
		if _, err := tw.Write(content); err != nil {
			return
		}
	}
	io.Copy(io.Discard, r.Body)
}
