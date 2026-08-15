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

## Future (per docs/fleet-bootstrap.md)

- Dependency resolution from the `deps` manifest field.
- Repo semantics (the brain's ginger-update-server) — nodes pull signed
  bundles over LAN.
- First-boot systemd one-shot in the ISO rootfs to provision /opt/ginger.
