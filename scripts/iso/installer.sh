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

# Create /etc/inittab if missing — SysVinit needs this to find TTYs
if [ ! -f "$MNT/etc/inittab" ]; then
    log_and_show "[STEP 4/6] Creating /etc/inittab (SysVinit config)..."
    cat > "$MNT/etc/inittab" << 'INITTAB'
# /etc/inittab — GingerOS SysVinit configuration
id:2:initdefault:

# System init script
si::sysinit:/etc/init.d/rcS

# Runlevels
l0:0:wait:/etc/init.d/rc 0
l1:1:wait:/etc/init.d/rc 1
l2:2:wait:/etc/init.d/rc 2
l3:3:wait:/etc/init.d/rc 3
l4:4:wait:/etc/init.d/rc 4
l5:5:wait:/etc/init.d/rc 5
l6:6:wait:/etc/init.d/rc 6

# Emergency shell on failure
z6:6:respawn:/sbin/sulogin

# Ctrl+Alt+Del
ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

# Virtual consoles
1:2345:respawn:/sbin/getty 38400 tty1
2:23:respawn:/sbin/getty 38400 tty2
3:23:respawn:/sbin/getty 38400 tty3
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
127.0.0.1   localhost
127.0.1.1   gingeros
::1         localhost ip6-localhost ip6-loopback
HOSTS

# ── Network, Silence & Identity ────────────────────────────────────────────
log_and_show "[STEP 6/6] Configuring LFS Networking (Static QEMU Config)..."
mkdir -p "$MNT/etc/sysconfig"
mkdir -p "$MNT/etc/init.d"

# Detect interface for config naming (fallback to eth0)
MAIN_IFACE=$(ls /sys/class/net | grep -v lo | head -n1 || echo "eth0")

# 1. Create LFS-style static config
cat > "$MNT/etc/sysconfig/ifconfig.$MAIN_IFACE" << EOF
ONBOOT=yes
IFACE=$MAIN_IFACE
SERVICE=ipv4-static
IP=10.0.2.15
GATEWAY=10.0.2.2
PREFIX=24
BROADCAST=10.0.2.255
EOF

# 2. Setup DNS
cat > "$MNT/etc/resolv.conf" << 'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
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

# 3. Create the missing 'rc' script that init is looking for
cat > "$MNT/etc/init.d/rc" << 'RC'
#!/bin/sh
# Minimal runlevel handler
echo "Entering runlevel $1..."
RC
chmod +x "$MNT/etc/init.d/rc"

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

# ── Network Bring-up (In rcS) ──────────────────────────────────────────────
cat > "$MNT/etc/init.d/rcS" << 'RCS'
#!/bin/sh
# Clean path for LFS
export PATH=/bin:/usr/bin:/sbin:/usr/sbin
# Refresh library cache using LFS config only
ldconfig -X

# GingerOS System Startup Script
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mount -o remount,rw /

# Set Identity
if [ -f /etc/hostname ]; then hostname -F /etc/hostname; fi
# Silence noise
dmesg -n 1

# Network Initialization
ip link set lo up
IFACE=$(ls /sys/class/net | grep -v lo | head -n1)
if [ -n "$IFACE" ]; then
    ip link set "$IFACE" up
    ip addr add 10.0.2.15/24 dev "$IFACE" 2>/dev/null
    ip route add default via 10.0.2.2 dev "$IFACE" 2>/dev/null
    ip addr show "$IFACE" | grep "inet "
    echo "Default Route:"
    ip route show | grep default
else
    echo "[WARN] No network interface found!"
fi
RCS
chmod +x "$MNT/etc/init.d/rcS"

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
      systemd.show_status=1
}

menuentry 'GingerOS (UUID)' {
    linux /boot/vmlinuz-ginger \
      root=UUID=$ROOT_UUID \
      rw rootwait \
      systemd.show_status=1
}

menuentry 'GingerOS Recovery Shell' {
    linux /boot/vmlinuz-ginger \
      root=/dev/sda1 \
      rw rootwait \
      init=/bin/sh
}
EOF

sync
log_and_show "[STEP 6/6] ════════════════════════════════════════"
log_and_show "[OK] GingerOS deployment COMPLETE!"
log_and_show "[OK] Remove install media and reboot."
log_and_show "[STEP 6/6] ════════════════════════════════════════"