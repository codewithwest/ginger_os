#!/bin/bash
# inject-firstboot.sh — bundle the first-boot provisioning payload into the
# LFS rootfs tarball.
#
#   ./lfs/iso/inject-firstboot.sh [ROOTFS_TARBALL] [--server URL] [--package NAME]
#
# The payload is merged into the SINGLE gzip stream of the rootfs tarball:
#   1. decompress the existing rootfs tar
#   2. tar --append the firstboot tree (units, script, static ginger-pkg,
#      signed seed bundle, trust key, brain address)
#   3. recompress + atomically replace
#
# Idempotent: a sidecar marker (<tarball>.firstboot) records the payload hash;
# if it matches, the injector is a no-op so the 1.9G cache is rebuilt once.
#
# The first-boot systemd one-shot (ginger-firstboot.service) then provisions
# /opt/ginger and enables the update timer on a fresh install.
set -eu

HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ROOT="$HERE/../.."
GINGER_PKG_DIR="$ROOT/ginger-pkg"
FIRSTBOOT_DIR="$HERE/firstboot"

ROOTFS_TARBALL="${1:-$ROOT/gingeros-lfs-rootfs.tar.gz}"
UPDATE_SERVER="${UPDATE_SERVER:-http://brain:8081}"
UPDATE_PACKAGE="${UPDATE_PACKAGE:-ginger-room-node}"
BUNDLE_PAYLOAD="${BUNDLE_PAYLOAD:-}"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# ── Payload staging ────────────────────────────────────────────────────────
stage_payload() {
    mkdir -p "$WORK/root/opt/ginger/bin" "$WORK/root/opt/ginger/keys" \
             "$WORK/root/opt/ginger/seed" "$WORK/root/usr/lib/systemd/system" \
             "$WORK/root/usr/local/sbin"
    cp -a "$FIRSTBOOT_DIR/root/usr/." "$WORK/root/usr/"
    cp -a "$FIRSTBOOT_DIR/root/opt/." "$WORK/root/opt/"

    # static ginger-pkg
    echo "[inject-firstboot] building static ginger-pkg"
    ( cd "$GINGER_PKG_DIR" && CGO_ENABLED=0 go build -buildvcs=false -o "$WORK/root/opt/ginger/bin/ginger-pkg" . )

    # signing key (reuse brain's keypair if present)
    KEY_DIR="${GINGER_SIGNING_KEY_DIR:-$ROOT/.signing}"
    mkdir -p "$KEY_DIR"
    KEY="$KEY_DIR/signing.key"
    PUB="$KEY_DIR/signing.pub"
    if [ ! -f "$KEY" ] || [ ! -f "$PUB" ]; then
        echo "[inject-firstboot] generating signing keypair"
        "$WORK/root/opt/ginger/bin/ginger-pkg" keygen --pub "$PUB" --priv "$KEY"
    fi
    install -m 0644 "$PUB" "$WORK/root/opt/ginger/seed/signing.pub"

    # seed bundle payload (default: placeholder; override via BUNDLE_PAYLOAD)
    if [ -z "$BUNDLE_PAYLOAD" ]; then
        SEED_PAYLOAD="$WORK/seed-payload"
        mkdir -p "$SEED_PAYLOAD/usr/bin"
        cat > "$SEED_PAYLOAD/usr/bin/ginger-room-node" << 'NODE'
#!/bin/sh
echo "[ginger-room-node] placeholder — replace with the real merged agent"
NODE
        chmod +x "$SEED_PAYLOAD/usr/bin/ginger-room-node"
    else
        SEED_PAYLOAD="$BUNDLE_PAYLOAD"
    fi

    echo "[inject-firstboot] signing seed bundle '$UPDATE_PACKAGE' v1.0.0"
    "$WORK/root/opt/ginger/bin/ginger-pkg" bundle create \
        --name "$UPDATE_PACKAGE" --version 1.0.0 \
        --key "$KEY" --dir "$SEED_PAYLOAD" \
        -o "$WORK/root/opt/ginger/seed/$UPDATE_PACKAGE-1.0.0.gingerbundle"

    # brain address + tracked package (read at first boot)
    echo "$UPDATE_SERVER" > "$WORK/root/opt/ginger/seed/update-server"
    echo "$UPDATE_PACKAGE" > "$WORK/root/opt/ginger/seed/update-package"
}

# Deterministic payload fingerprint (no mtimes): config args + key + binary.
payload_hash() {
    # Hash CONTENT only (relative paths -> sha256sum output is path-independent).
    local HASH_WORK="$WORK/hash"
    mkdir -p "$HASH_WORK"
    cp "$KEY" "$HASH_WORK/key"
    cp "$PUB" "$HASH_WORK/pub"
    cp "$WORK/root/opt/ginger/bin/ginger-pkg" "$HASH_WORK/ginger-pkg"
    {
        echo "PAYLOAD_VERSION=4"
        echo "UPDATE_SERVER=$UPDATE_SERVER"
        echo "UPDATE_PACKAGE=$UPDATE_PACKAGE"
        # Content hash of the firstboot unit/script tree (path-independent),
        # including symlink targets so new links force a re-inject.
        ( cd "$FIRSTBOOT_DIR/root" && find . ! -type d -print0 | sort -z | xargs -0 -I{} sh -c \
            'if [ -L "$1" ]; then printf "%s -> %s\n" "$1" "$(readlink "$1")"; else sha256sum "$1"; fi' _ {} )
        ( cd "$HASH_WORK" && sha256sum key pub ginger-pkg )
    } | sha256sum | awk '{print $1}'
}

if [ ! -f "$ROOTFS_TARBALL" ]; then
    echo "[inject-firstboot] ERROR: no rootfs tarball at $ROOTFS_TARBALL"
    exit 1
fi

MARKER="$ROOTFS_TARBALL.firstboot"
stage_payload
NEW_HASH="$(payload_hash)"

if [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "$NEW_HASH" ]; then
    echo "[inject-firstboot] payload unchanged; skipping (rootfs already provisioned)"
    exit 0
fi

echo "[inject-firstboot] merging payload into $ROOTFS_TARBALL"
echo "[inject-firstboot] decompressing (first run may take a minute for the 1.9G cache)"
if command -v pigz >/dev/null 2>&1; then
    pigz -dc "$ROOTFS_TARBALL" > "$WORK/rootfs.tar"
else
    zcat "$ROOTFS_TARBALL" > "$WORK/rootfs.tar"
fi
tar --append --file "$WORK/rootfs.tar" --directory "$WORK/root" . 2>/dev/null \
    || tar -rf "$WORK/rootfs.tar" -C "$WORK/root" .
if command -v pigz >/dev/null 2>&1; then
    pigz -9 -c "$WORK/rootfs.tar" > "$WORK/rootfs.new.tar.gz"
else
    gzip -9 -c "$WORK/rootfs.tar" > "$WORK/rootfs.new.tar.gz"
fi
install -m 0644 "$WORK/rootfs.new.tar.gz" "$ROOTFS_TARBALL"
echo "$NEW_HASH" > "$MARKER"

echo "[inject-firstboot] done. payload entries now in rootfs:"
tar -tzf "$ROOTFS_TARBALL" | grep -E 'opt/ginger/(bin|seed|keys)|ginger-(firstboot|update)' | head -20
