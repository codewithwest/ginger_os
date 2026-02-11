#!/bin/bash
# GingerOS - Finalize Base RootFS Image (Generic)
# Prepares a deployable, bootable LFS root filesystem image
# Does NOT install GRUB to a real disk
# Adds minimal init scripts and generic users for testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

ROOTFS="${GINGER_ROOT}/rootfs"   # Path to your chroot rootfs folder
log "PROCESS" "Starting finalization of GingerOS base root filesystem..."

# ---------------------------------------------------------------------
# Step 0 — ensure ROOTFS exists
# ---------------------------------------------------------------------
if [ ! -d "$ROOTFS" ]; then
    log "ERROR" "RootFS directory $ROOTFS does not exist. Build failed?"
    exit 1
fi

# ---------------------------------------------------------------------
# Step 1 — Clean temp files and machine-specific data
# ---------------------------------------------------------------------
log "INFO" "Cleaning temporary files..."
rm -rf "$ROOTFS"/tmp/*
rm -rf "$ROOTFS"/var/tmp/*
find "$ROOTFS"/var/log -type f -exec truncate -s 0 {} \;
rm -f "$ROOTFS"/etc/ssh/ssh_host_* 2>/dev/null || true
rm -f "$ROOTFS"/etc/machine-id 2>/dev/null || true
rm -f "$ROOTFS"/root/.bash_history

# ---------------------------------------------------------------------
# Step 2 — Minimal init scripts
# ---------------------------------------------------------------------
log "INFO" "Creating minimal init scripts..."
mkdir -p "$ROOTFS"/etc/rc.d

cat > "$ROOTFS"/etc/rc.d/rc.sysinit << 'RC_SYSINIT'
#!/bin/bash
# Minimal system initialization
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs tmpfs /run
mount -o remount,rw /
[ -z "$(cat /etc/hostname 2>/dev/null)" ] && echo "gingeros" > /etc/hostname
echo "Minimal rc.sysinit complete"
RC_SYSINIT

chmod +x "$ROOTFS"/etc/rc.d/rc.sysinit

cat > "$ROOTFS"/etc/rc.d/rc << 'RC_MINIMAL'
#!/bin/bash
# Minimal rc script
/etc/rc.d/rc.sysinit
# exec /bin/bash
RC_MINIMAL

chmod +x "$ROOTFS"/etc/rc.d/rc

# ---------------------------------------------------------------------
# Step 3 — /etc/inittab
# ---------------------------------------------------------------------
cat > "$ROOTFS"/etc/inittab << 'INIT_EOF'
# Begin /etc/inittab
id:3:initdefault:
si::sysinit:/etc/rc.d/rc
1:2345:respawn:/sbin/agetty -L tty1 9600 vt100
2:2345:respawn:/sbin/agetty -L tty2 9600 vt100
3:2345:respawn:/sbin/agetty -L tty3 9600 vt100
4:2345:respawn:/sbin/agetty -L tty4 9600 vt100
5:2345:respawn:/sbin/agetty -L tty5 9600 vt100
6:2345:respawn:/sbin/agetty -L tty6 9600 vt100
# End /etc/inittab
INIT_EOF

# ---------------------------------------------------------------------
# Step 4 — Generic users
# ---------------------------------------------------------------------
log "INFO" "Creating generic root and user accounts..."
sudo chroot "$ROOTFS" /bin/bash -c "
set -e
echo 'root:root' | chpasswd

if ! id ginger >/dev/null 2>&1; then
    groupadd ginger
    useradd -m -g ginger -s /bin/bash ginger
    echo 'ginger:ginger' | chpasswd
fi
"

# ---------------------------------------------------------------------
# Step 5 — Prepare GRUB files (no disk install)
# ---------------------------------------------------------------------
log "INFO" "Preparing GRUB config for future installer..."
mkdir -p "$ROOTFS"/boot/grub
cat > "$ROOTFS"/boot/grub/grub.cfg << 'GRUB_EOF'
set default=0
set timeout=5

insmod part_msdos
insmod ext2

set root=(hd0,msdos1)

menuentry 'GingerOS (LFS Base)' {
    linux /boot/vmlinuz root=/dev/sda1 rw console=tty0
}
GRUB_EOF

# Note: actual grub-install to a disk will be done by installer script later

# ---------------------------------------------------------------------
# Step 6 — Package rootfs for installer
# ---------------------------------------------------------------------
OUTPUT_TAR="${GINGER_ROOT}/gingeros-base-rootfs.tar"
log "INFO" "Packaging root filesystem into $OUTPUT_TAR..."
sudo tar --xattrs --acls -C "$ROOTFS" -cpf "$OUTPUT_TAR" .

log "SUCCESS" "GingerOS base root filesystem finalized."
log "INFO" "Installer can now deploy $OUTPUT_TAR to target disks."
