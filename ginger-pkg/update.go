package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// updateServer is the wire format for the /v1/packages response.
type updateServer struct {
	Packages map[string][]serverPackage `json:"-"`
}

// fetchPackages queries the brain for available package versions.
func fetchPackages(serverURL string) (map[string][]serverPackage, error) {
	resp, err := http.Get(strings.TrimRight(serverURL, "/") + "/v1/packages")
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("server returned %s", resp.Status)
	}
	var out map[string][]serverPackage
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	return out, nil
}

// fetchBundle downloads a signed bundle from the brain to destPath.
func fetchBundle(serverURL, name, version, destPath string) error {
	url := fmt.Sprintf("%s/v1/bundle/%s/%s", strings.TrimRight(serverURL, "/"), name, version)
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("server returned %s for %s/%s", resp.Status, name, version)
	}
	out, err := os.Create(destPath)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, resp.Body)
	return err
}

// updatePackage compares the local version against the server's latest for
// one package and upgrades if a newer signed bundle is available.
func updatePackage(serverURL, name, trustedKey string) (bool, error) {
	remote, err := fetchPackages(serverURL)
	if err != nil {
		return false, err
	}
	avail := remote[name]
	if len(avail) == 0 {
		return false, nil
	}
	latest := avail[0].Version // already sorted desc by server

	st, err := loadState()
	if err != nil {
		return false, err
	}
	entry := st.Packages[name]
	if entry != nil && compareVersions(entry.ActiveVersion, latest) >= 0 {
		return false, nil // up to date
	}

	tmp, err := os.CreateTemp("", "ginger-update-*.gingerbundle")
	if err != nil {
		return false, err
	}
	tmpPath := tmp.Name()
	tmp.Close()
	defer os.Remove(tmpPath)

	if err := fetchBundle(serverURL, name, latest, tmpPath); err != nil {
		return false, err
	}
	// Trusted-key env must be visible to the nested install path.
	os.Setenv("GINGER_TRUSTED_KEY", trustedKey)
	if err := installBundle(tmpPath, true); err != nil {
		return false, err
	}
	return true, nil
}

// cmdUpdate is the node-side update agent.
// Usage: ginger-pkg update --server http://brain:8081 [--name PKG] [--once] [--interval 60] [--trusted-key FILE]
func cmdUpdate(args []string) error {
	serverURL := ""
	name := ""
	once := false
	interval := 60
	trustedKey := ""
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--server":
			serverURL = next(args, &i)
		case "--name":
			name = next(args, &i)
		case "--once":
			once = true
		case "--interval":
			if n, err := parseInt(args, &i); err == nil {
				interval = n
			}
		case "--trusted-key":
			trustedKey = next(args, &i)
		}
	}
	if serverURL == "" {
		return fmt.Errorf("update needs --server URL")
	}
	if trustedKey == "" {
		trustedKey = filepath.Join(RootDir, "keys", "signing.pub")
	}

	for {
		ok, err := runUpdate(serverURL, name, trustedKey)
		if err != nil {
			fmt.Printf("[update] error: %v\n", err)
		} else if ok {
			fmt.Printf("[update] %s upgraded\n", nameOrAll(name))
		}
		if once {
			return nil
		}
		time.Sleep(time.Duration(interval) * time.Second)
	}
}

func runUpdate(serverURL, name, trustedKey string) (bool, error) {
	if name != "" {
		return updatePackage(serverURL, name, trustedKey)
	}
	remote, err := fetchPackages(serverURL)
	if err != nil {
		return false, err
	}
	any := false
	for pkg := range remote {
		ok, err := updatePackage(serverURL, pkg, trustedKey)
		if err != nil {
			fmt.Printf("[update] %s: %v\n", pkg, err)
			continue
		}
		any = any || ok
	}
	return any, nil
}

func nameOrAll(name string) string {
	if name == "" {
		return "(all packages)"
	}
	return name
}

func parseInt(args []string, i *int) (int, error) {
	*i++
	if *i >= len(args) {
		return 0, fmt.Errorf("missing value")
	}
	var n int
	if _, err := fmt.Sscanf(args[*i], "%d", &n); err != nil {
		return 0, err
	}
	return n, nil
}
