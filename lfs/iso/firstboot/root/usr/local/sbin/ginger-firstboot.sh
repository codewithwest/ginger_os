#!/bin/bash
# ginger-firstboot.sh — one-shot provisioning for a fresh GingerOS install.
# Runs exactly once (via ginger-firstboot.service + a stamp file), then
# hands off to the ginger-update agent for all future updates.
set -eu

GINGER_ROOT="${GINGER_ROOT:-/opt/ginger}"
STAMP="$GINGER_ROOT/.provisioned"
LOG="$GINGER_ROOT/firstboot.log"

mkdir -p "$GINGER_ROOT/bin" "$GINGER_ROOT/keys" "$GINGER_ROOT/seed" "$GINGER_ROOT/bundles" "$GINGER_ROOT/current"
exec > >(tee -a "$LOG") 2>&1

log() { echo "[firstboot] $*"; }

# Re-run guard: if we already provisioned, just make sure the update agent runs.
if [ -f "$STAMP" ]; then
    log "already provisioned; skipping"
    systemctl enable --now ginger-update.timer 2>/dev/null || true
    exit 0
fi

log "provisioning GingerOS node at $GINGER_ROOT"

# 1. ginger-pkg must exist (shipped by the ISO payload in /opt/ginger/bin).
if [ ! -x "$GINGER_ROOT/bin/ginger-pkg" ]; then
    log "ERROR: ginger-pkg binary missing at $GINGER_ROOT/bin/ginger-pkg"
    exit 1
fi
log "ginger-pkg ready: $("$GINGER_ROOT/bin/ginger-pkg" version 2>/dev/null || echo present)"

# 2. Install the seeded signing public key (trust anchor).
if [ -f "$GINGER_ROOT/seed/signing.pub" ]; then
    install -m 0644 "$GINGER_ROOT/seed/signing.pub" "$GINGER_ROOT/keys/signing.pub"
    log "installed trusted signing key"
fi

# 3. Install the seeded room-node bundle if present.
SEED_BUNDLE=$(ls "$GINGER_ROOT/seed/"*.gingerbundle 2>/dev/null | head -n1 || true)
if [ -n "$SEED_BUNDLE" ] && [ -x "$GINGER_ROOT/bin/ginger-pkg" ]; then
    GINGER_ROOT="$GINGER_ROOT" GINGER_TRUSTED_KEY="$GINGER_ROOT/keys/signing.pub" \
        "$GINGER_ROOT/bin/ginger-pkg" install "$SEED_BUNDLE"
    log "installed seed bundle: $(basename "$SEED_BUNDLE")"
fi

# 4. Write the brain update-server config as a systemd EnvironmentFile,
#    then enable the update agent (pulls signed bundles over LAN).
UPDATE_SERVER=$(cat "$GINGER_ROOT/seed/update-server" 2>/dev/null || echo "http://brain:8081")
UPDATE_PACKAGE=$(cat "$GINGER_ROOT/seed/update-package" 2>/dev/null || echo "")
printf 'UPDATE_SERVER=%s\nUPDATE_PACKAGE=%s\n' "$UPDATE_SERVER" "$UPDATE_PACKAGE" \
    > "$GINGER_ROOT/update-server"
log "update server: $UPDATE_SERVER  package: ${UPDATE_PACKAGE:-<all>}"
systemctl enable --now ginger-update.timer 2>/dev/null || log "WARN: could not enable update timer"

# 5. Stamp to make this a one-shot.
touch "$STAMP"
log "provisioning complete"
