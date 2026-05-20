#!/usr/bin/env bash
set -euo pipefail

# fd 3 = log file (silent, for debugging after the fact)
LOG_FILE="/tmp/install.log"
mkdir -p /tmp
exec 3>"$LOG_FILE"
# Silence stderr into the log so trace/tool noise doesn't appear in the TUI
exec 2>&3

log_and_show() {
    echo "$1"       # → Python TUI subprocess pipe (stdout)
    echo "$1" >&3  # → /tmp/install.log
}

TARGET_DEV="${1:-}"
if [ -z "$TARGET_DEV" ]; then
  echo "Usage: $0 /dev/sdX"
  exit 1
fi

MNT="/mnt/ginger"
ROOT_PART="${TARGET_DEV}1"

log_and_show "[STEP 0/6] ═══════════════════════════════════════"
log_and_show "[STEP 0/6] GingerOS Installer — Target: $TARGET_DEV"
log_and_show "[STEP 0/6] ═══════════════════════════════════════"

log_and_show "[STEP 1/6] Wiping old signatures..."
wipefs -a "$TARGET_DEV" >&3 2>&3 || true

log_and_show "[STEP 1/6] Partitioning disk (MBR)..."
parted -s "$TARGET_DEV" mklabel msdos >&3 2>&3
parted -s "$TARGET_DEV" mkpart primary ext4 1MiB 100% >&3 2>&3
partprobe "$TARGET_DEV" >&3 2>&3
udevadm settle >&3 2>&3
sleep 2

log_and_show "[STEP 2/6] Formatting root partition $ROOT_PART as ext4..."
mkfs.ext4 -F "$ROOT_PART" >&3 2>&3
partprobe "$TARGET_DEV" >&3 2>&3
udevadm settle >&3 2>&3
sleep 2

log_and_show "[STEP 3/6] Mounting $ROOT_PART..."
mkdir -p "$MNT"
mount "$ROOT_PART" "$MNT" >&3 2>&3

log_and_show "[STEP 4/6] Extracting root filesystem (this may take a while)..."
# tar -v streams each filename to stdout → shows up in TUI live stream
tar -xpvf /mnt/iso/installer/gingeros-base-rootfs.tar.gz -C "$MNT" 2>&3 | \
    while IFS= read -r line; do
        log_and_show "  EXTRACT: $line"
    done
log_and_show "[STEP 4/6] Extraction complete."

# -----------------------------------------------------------------
# 5️⃣  Create the required absolute merged‑/usr symlinks inside the new root
# -----------------------------------------------------------------
# These links must be absolute because early‑boot scripts run before any
# chroot or working‑directory context exists.  They replace the relative links
# that were previously created by update-dir.sh.
log_and_show "[STEP 5/6] Creating absolute merged‑/usr symlinks..."

# Helper to (re)create an absolute symlink, removing any existing entry first
create_abs_link() {
    local target="$1"
    local link="$2"
    if [ -e "$MNT/$link" ]; then
        rm -rf "$MNT/$link"
    fi
    ln -sv "$target" "$MNT/$link"
    log_and_show "    $link -> $target"
}

# remove_abs_link() {
#     local link="$1"
#     if [ -L "$MNT/$link" ]; then
#         rm -rf "$MNT/$link"
#         log_and_show "    Removed existing symlink: $link"
#     fi
# }

# bin, sbin, lib
# create_abs_link "/usr/bin"   "/bin"
# create_abs_link "/usr/sbin"  "/sbin"
# create_abs_link "/usr/lib"   "/lib"

# lib64 – point to /usr/lib64 if it exists, otherwise to /usr/lib
# if [ -d "$MNT/usr/lib64" ]; then
#     lib64_target="/usr/lib64"
# else
#     lib64_target="/usr/lib"
# fi
# create_abs_link "$lib64_target" "lib64"

 
log_and_show "[STEP 5/6] Absolute symlinks created."

# Create /etc/inittab — LFS Standard (Section 7.6.2)
if [ ! -f "$MNT/etc/inittab" ]; then
    log_and_show "[STEP 4/6] Creating /etc/inittab (LFS standard)..."
    cat > "$MNT/etc/inittab" << 'INITTAB'
# /etc/inittab — GingerOS LFS configuration
id:3:initdefault:

si::sysinit:/etc/rc.d/init.d/rc S

l0:0:wait:/etc/rc.d/init.d/rc 0
l1:S1:wait:/etc/rc.d/init.d/rc 1
l2:2:wait:/etc/rc.d/init.d/rc 2
l3:3:wait:/etc/rc.d/init.d/rc 3
l4:4:wait:/etc/rc.d/init.d/rc 4
l5:5:wait:/etc/rc.d/init.d/rc 5
l6:6:wait:/etc/rc.d/init.d/rc 6

ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

su:S016:once:/sbin/sulogin

1:2345:respawn:/sbin/agetty --noclear tty1 9600
2:2345:respawn:/sbin/agetty tty2 9600
3:2345:respawn:/sbin/agetty tty3 9600
INITTAB
    log_and_show "[STEP 4/6] /etc/inittab created."
fi

log_and_show "[STEP 4/6] Installing kernel..."
mkdir -p "$MNT/boot"
cp /mnt/iso/boot/vmlinuz "$MNT/boot/vmlinuz-ginger" >&3 2>&3
log_and_show "[STEP 4/6] Kernel installed."

udevadm settle >&3 2>&3
sleep 1

log_and_show "[STEP 5/6] Detecting partition UUID..."
ROOT_UUID=""
for i in 1 2 3 4 5; do
    ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART" 2>&3 || true)
    if [ -n "$ROOT_UUID" ]; then
        break
    fi
    log_and_show "[STEP 5/6] Retrying UUID detection ($i/5)..."
    sleep 1
done

if [ -z "$ROOT_UUID" ]; then
    ROOT_UUID=$(lsblk -no UUID "$ROOT_PART" 2>&3 | head -n1 || true)
fi

if [ -z "$ROOT_UUID" ]; then
    log_and_show "[ERROR] Failed to detect UUID for $ROOT_PART"
    exit 1
fi
log_and_show "[STEP 5/6] Root UUID: $ROOT_UUID"

log_and_show "[STEP 6/6] Installing GRUB bootloader..."
mount --bind /dev  "$MNT/dev"  >&3 2>&3
mount --bind /proc "$MNT/proc" >&3 2>&3
mount --bind /sys  "$MNT/sys"  >&3 2>&3

grub-install --target=i386-pc --boot-directory="$MNT/boot" "$TARGET_DEV" >&3 2>&3
log_and_show "[STEP 6/6] GRUB installed."

# ── System Identity ────────────────────────────────────────────────────────
log_and_show "[STEP 6/6] Setting hostname: gingeros..."
echo "gingeros" > "$MNT/etc/hostname"
cat > "$MNT/etc/hosts" << 'HOSTS'
# Begin /etc/hosts (Section 7.5.4)
127.0.0.1   localhost.localdomain localhost
127.0.1.1   gingeros.example.org gingeros
::1         localhost.localdomain localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
# End /etc/hosts
HOSTS

# ── Network, Silence & Identity ────────────────────────────────────────────
log_and_show "[STEP 6/6] Configuring LFS Networking..."
mkdir -p "$MNT/etc/sysconfig"

# Detect interface for config naming (fallback to eth0)
MAIN_IFACE=$(ls /sys/class/net | grep -v lo | head -n1 || echo "eth0")

# Determine IP settings (QEMU vs Bare Metal)
IP="192.168.1.2"
GW="192.168.1.1"
PREFIX="24"
BROADCAST="192.168.1.255"

if grep -qi "qemu" /sys/class/dmi/id/sys_vendor 2>/dev/null || grep -qi "qemu" /proc/cpuinfo; then
    log_and_show "[STEP 6/6] Detected QEMU environment - applying virtual network defaults."
    IP="10.0.2.15"
    GW="10.0.2.2"
    BROADCAST="10.0.2.255"
fi

# 1. Create LFS-style configuration (Section 7.5.1)
cat > "$MNT/etc/sysconfig/ifconfig.$MAIN_IFACE" << EOF
ONBOOT=yes
IFACE=$MAIN_IFACE
SERVICE=ipv4-static
IP=$IP
GATEWAY=$GW
PREFIX=$PREFIX
BROADCAST=$BROADCAST
EOF

# 2. Setup DNS (Section 7.5.2)
cat > "$MNT/etc/resolv.conf" << 'EOF'
# Begin /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
# End /etc/resolv.conf
EOF

# ── Library & System Health Fixups ─────────────────────────────────────────
log_and_show "[STEP 6/6] Sanitizing library environment..."
# 1. Force a clean LFS library configuration (no Ubuntu paths!)
cat > "$MNT/etc/ld.so.conf" << 'LDCONF'
/lib
/usr/lib
/usr/local/lib
LDCONF

# 2. Ensure /lib64 is correct and kill any host-style subdirs
rm -rf "$MNT/lib/x86_64-linux-gnu"
rm -rf "$MNT/usr/lib/x86_64-linux-gnu"
if [ ! -L "$MNT/lib64" ]; then rm -rf "$MNT/lib64"; ln -sf lib "$MNT/lib64"; fi

# 3. Ensure standard LFS bootscript paths
if [ -d "$MNT/etc/rc.d/init.d" ] && [ ! -L "$MNT/etc/init.d" ]; then
    log_and_show "[STEP 6/6] Linking /etc/init.d to /etc/rc.d/init.d..."
    rm -rf "$MNT/etc/init.d"
    ln -sf rc.d/init.d "$MNT/etc/init.d"
fi

# ── Raw Network Test Tool ──────────────────────────────────────────────────
cat > "$MNT/usr/bin/net-test" << 'TEST'
#!/bin/bash
echo "--- GingerOS Network Health Check ---"
echo "1. Checking Loopback..."
ip addr show lo | grep -q "UP" && echo "[OK] Loopback is UP" || echo "[FAIL] Loopback is DOWN"

echo "2. Checking Gateway..."
ip route | grep -q "default" && echo "[OK] Default route exists" || echo "[FAIL] No default route"

echo "3. Testing Raw DNS Connection (UDP 53)..."
# Try to open a raw socket to Google DNS
(echo > /dev/udp/8.8.8.8/53) >/dev/null 2>&1 && echo "[OK] Can reach Google DNS" || echo "[FAIL] Internet unreachable"

echo "4. Testing HTTP Handshake (TCP 80)..."
(echo > /dev/tcp/google.com/80) >/dev/null 2>&1 && echo "[OK] Web handshake successful" || echo "[FAIL] Web unreachable"
TEST
chmod +x "$MNT/usr/bin/net-test"

# ── Boot Sequence Finalization ─────────────────────────────────────────────
log_and_show "[STEP 6/6] Finalizing boot sequence..."
# We now rely on standard LFS-bootscripts handled by /etc/rc.d/init.d/rc.
# No manual rcS is needed if the rootfs extraction is complete.

# Ensure ldconfig is run on first boot or now
if command -v chroot >/dev/null 2>&1; then
    chroot "$MNT" ldconfig
fi

# ── User & Password Setup ──────────────────────────────────────────────────
log_and_show "[STEP 6/6] Creating user: $NEW_USER..."
# Create user in the installed rootfs via chroot (non-fatal if chroot missing)
if command -v chroot >/dev/null 2>&1; then
    chroot "$MNT" /bin/bash -c "
        useradd -m -s /bin/bash '$NEW_USER' 2>/dev/null || true
        echo 'root:$ROOT_PASS' | chpasswd
        echo '$NEW_USER:$NEW_PASS' | chpasswd
        grep -q '^sudo:' /etc/group && usermod -aG sudo '$NEW_USER' || true
        # Set hostname in current session if possible
        hostname gingeros 2>/dev/null || true
    " >&3 2>&3 && log_and_show "[STEP 6/6] User '$NEW_USER' created." \
              || log_and_show "[WARN] User creation encountered errors (non-fatal)."
else
    log_and_show "[WARN] chroot not available — skipping user creation. Set password on first boot."
fi

# ── GingerOS Branding ──────────────────────────────────────────────────────
cat > "$MNT/etc/issue" << 'ISSUE'

   ____ _                         ____  ____ 
  / ___(_)_ __   __ _  ___ _ __  / __ \/ ___|
 | |  _| | '_ \ / _` |/ _ \ '__|| |  | \___ \ 
 | |_| | | | | | (_| |  __/ |   | |__| |___) |
  \____|_|_| |_|\__, |\___|_|    \____/|____/ 
                 |___/                        

 GingerOS LFS Edition - \l
Kernel \r on an \m

ISSUE

log_and_show "[STEP 6/6] Writing GRUB config..."
mkdir -p "$MNT/boot/grub"

cat << EOF > "$MNT/boot/grub/grub.cfg"
set default=0
set timeout=5

menuentry 'GingerOS' {
    linux /boot/vmlinuz-ginger \
      root=/dev/sda1 \
      rw rootwait \
      systemd.show_status=1 \
      net.ifnames=0
}

menuentry 'GingerOS (UUID)' {
    linux /boot/vmlinuz-ginger \
      root=UUID=$ROOT_UUID \
      rw rootwait \
      systemd.show_status=1 \
      net.ifnames=0
}

menuentry 'GingerOS Recovery Shell' {
    linux /boot/vmlinuz-ginger \
      root=/dev/sda1 \
      rw rootwait \
      init=/bin/sh \
      net.ifnames=0
}
EOF

sync
log_and_show "[STEP 6/6] ════════════════════════════════════════"
log_and_show "[OK] GingerOS deployment COMPLETE!"
log_and_show "[OK] Remove install media and reboot."
log_and_show "[STEP 6/6] ════════════════════════════════════════"