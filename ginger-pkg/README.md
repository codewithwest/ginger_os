# ginger-pkg — GingerOS package manager

Standalone static Go binary for installing, upgrading, verifying and rolling
back signed application bundles on GingerOS machines. Zero runtime deps
(stdlib only: ed25519, tar, sha256). Runs on the brain (full stack) and on
room nodes (single room bundle).

## Build

```bash
cd ginger-pkg
go build -o ginger-pkg .            # dynamic (uses cgo for ed25519 speed)
CGO_ENABLED=0 go build -o ginger-pkg .   # fully static, for the ISO/rootfs
```

## Store layout

```
/opt/ginger/
├── bundles/<name>/<version>/files/...   installed payload
├── current/<name>  -> ../../bundles/<name>/<version>   (atomic symlink)
├── keys/signing.pub                      trusted public key (from brain)
└── state.json                            installed set + versions
```

`GINGER_ROOT` env overrides the store root (used for smoke tests). `GINGER_TRUSTED_KEY`
points at the public key that must have signed the bundle; defaults to
`$GINGER_ROOT/keys/signing.pub`. When the file is absent, trust is NOT
enforced — provision it on every machine that should accept bundles.

## Commands

```
ginger-pkg keygen [--pub FILE] [--priv FILE]
    Generate an ed25519 keypair (brain holds priv, distributes pub).

ginger-pkg bundle create --name N --version V --key PRIV --dir PAYLOAD \
        [-o OUT] [--service UNIT ...]
    Build a signed .gingerbundle from a payload directory. PAYLOAD tree is
    shipped under files/; systemd units under PAYLOAD/etc/systemd/system/
    are installed when a matching --service is enabled.

ginger-pkg install BUNDLE        # verify sig + checksums, activate, start units
ginger-pkg upgrade BUNDLE        # install new version, keep previous for rollback
ginger-pkg remove NAME           # stop units, delete bundle + current link
ginger-pkg list                  # installed packages + versions
ginger-pkg verify NAME [VERSION] # re-check file checksums vs manifest
ginger-pkg status [NAME]         # per-package health (OK / DEGRADED)
ginger-pkg rollback NAME         # flip current symlink to previous version

ginger-pkg serve [--addr :8081] [--root /opt/ginger]
    Brain-side update server. Serves:
      GET /healthz                  health check
      GET /v1/packages              all packages + versions (JSON)
      GET /v1/bundle/<name>/<version>   signed .gingerbundle download
    Re-streams the signed bundle from the store, so it can serve anything
    that was installed locally (same verified bytes).

ginger-pkg update --server http://brain:8081 \
        [--name PKG] [--once] [--interval 60] [--trusted-key FILE]
    Node-side update agent. Polls the brain, compares the installed version
    against the latest available, pulls the signed bundle and installs it
    atomically. --once = single check then exit (systemd timer/one-shot);
    without it, loops forever (daemon). With no --name, updates all.
```

## Security model

- Bundle = gzip tarball: `manifest.json` (files, checksums, services) + `files/`.
- Manifest is **ed25519-signed** by the brain; the signature + signing key are
  embedded and verified on extract.
- Trusted-key enforcement: the manifest's signing key must match
  `GINGER_TRUSTED_KEY`. Prevents a rogue self-signed bundle from installing.
- Every file's sha256 is re-verified on extract and on `verify`.
- Activation is atomic: a temp symlink is renamed over `current/<name>`, so a
  crash never leaves a half-switched version.

## Fleet update flow (working)

```
Brain (serve)                          Room node (update)
ginger-pkg serve :8081                 ginger-pkg update --server http://brain:8081
  /v1/packages   ── available ───────▶    compares vs installed version
  /v1/bundle/…   ── signed bundle ────▶   verifies trusted key + checksums
                                          atomic symlink swap + service restart
```

- Sign bundles on the brain (`bundle create --key signing.key`).
- Provision `signing.pub` on each node (default trust path
  `$GINGER_ROOT/keys/signing.pub`).
- Run `update` on nodes as a systemd unit (one-shot timer or daemon).
- Rollback on any node: `ginger-pkg rollback <name>`.

## Future (per docs/fleet-bootstrap.md)

- Dependency resolution from the `deps` manifest field.
- First-boot systemd one-shot in the ISO rootfs to provision /opt/ginger.
