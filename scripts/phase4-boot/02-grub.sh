#!/bin/bash
# GingerOS - GRUB + init + users setup (Image-based)
# Mounts the LFS disk image, installs GRUB, sets up inittab, creates minimal rc.sysinit + rc, adds users, and cleans up

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

IMAGE="${GINGER_ROOT}/ginger_os.img"
MOUNT_POINT="/mnt/lfs"

log "PROCESS" "Starting final bootloader, init, and users setup on image..."

# ---------------------------------------------------------------------
# Step 0 — detach stale mounts / loop devices
# ---------------------------------------------------------------------
sudo umount -R "$MOUNT_POINT" 2>/dev/null || true
sudo losetup -D

# ---------------------------------------------------------------------
# Step 1 — setup loop device
# ---------------------------------------------------------------------
LOOP_DEV=$(sudo losetup -fP --show "$IMAGE")
log "INFO" "Loop device attached: $LOOP_DEV"

# ---------------------------------------------------------------------
# Step 2 — mount root partition
# ---------------------------------------------------------------------
sudo mkdir -p "$MOUNT_POINT"
sudo mount "${LOOP_DEV}p1" "$MOUNT_POINT"
log "INFO" "Partition mounted at $MOUNT_POINT"
df -h "$MOUNT_POINT"

# ---------------------------------------------------------------------
# Step 3 — mount virtual filesystems for chroot
# ---------------------------------------------------------------------
sudo mkdir -p "$MOUNT_POINT"/{dev,proc,sys,run}
sudo mount --bind /dev      "$MOUNT_POINT/dev"
sudo mount --bind /dev/pts  "$MOUNT_POINT/dev/pts"
sudo mount -t proc proc     "$MOUNT_POINT/proc"
sudo mount -t sysfs sysfs   "$MOUNT_POINT/sys"
sudo mount -t tmpfs tmpfs   "$MOUNT_POINT/run"

# ---------------------------------------------------------------------
# Step 4 — chroot and install GRUB + init scripts + users
# ---------------------------------------------------------------------
sudo chroot "$MOUNT_POINT" /bin/bash -c "
set -e

# --- /etc/fstab ---
echo 'Updating /etc/fstab...'
ROOT_UUID=\$(blkid -s UUID -o value /dev/loop0p1)
cat > /etc/fstab << EOF
UUID=\$ROOT_UUID    /            ext4   defaults            1 1
proc               /proc        proc   nosuid,noexec,nodev 0 0
sysfs              /sys         sysfs  nosuid,noexec,nodev 0 0
devpts             /dev/pts     devpts gid=5,mode=620    0 0
tmpfs              /run         tmpfs  defaults            0 0
tmpfs              /dev/shm     tmpfs  defaults            0 0
EOF

# --- GRUB installation ---
echo 'Installing GRUB...'
grub-install --target=i386-pc \
             --boot-directory=/boot \
             --modules='part_msdos ext2 biosdisk' \
             --no-floppy \
             /dev/loop0

echo 'Writing grub.cfg...'
cat > /boot/grub/grub.cfg << 'GRUB_EOF'
set default=0
set timeout=5

insmod part_msdos
insmod ext2

set root=(hd0,msdos1)

menuentry 'GingerOS (LFS 12.4)' {
    linux /boot/vmlinuz-6.16.1-lfs-12.4 root=/dev/sda1 rw console=ttyS0,115200
}
GRUB_EOF

# --- Create minimal rc.sysinit + rc ---
mkdir -p /etc/rc.d

cat > /etc/rc.d/rc.sysinit << 'RC_SYSINIT'
#!/bin/bash
# Minimal system initialization
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs tmpfs /run

# Remount root as read-write
mount -o remount,rw /

[ -z \"\$(cat /etc/hostname 2>/dev/null)\" ] && echo \"gingeros\" > /etc/hostname
echo \"Minimal rc.sysinit complete\"
RC_SYSINIT

chmod +x /etc/rc.d/rc.sysinit

cat > /etc/rc.d/rc << 'RC_MINIMAL'
#!/bin/bash
# Minimal rc script
/etc/rc.d/rc.sysinit
exec /bin/bash
RC_MINIMAL

chmod +x /etc/rc.d/rc

# --- /etc/inittab ---
cat > /etc/inittab << 'INIT_EOF'
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

# --- Create users ---
echo 'Setting root password...'
echo 'root:root' | chpasswd

if ! id ginger >/dev/null 2>&1; then
    groupadd ginger
    useradd -m -g ginger -s /bin/bash ginger
    echo 'ginger:ginger' | chpasswd
fi
"

# ---------------------------------------------------------------------
# Step 5 — cleanup mounts and loop device
# ---------------------------------------------------------------------
sudo umount -R "$MOUNT_POINT"
sudo losetup -d "$LOOP_DEV"

log "SUCCESS" "GRUB + init + users installed successfully inside image."
log "INFO" "Boot with:"
log "INFO" "  qemu-system-x86_64 -enable-kvm -m 2G -drive file=${IMAGE},format=raw -serial stdio"
log "INFO" "Login using 'root/root' or 'ginger/ginger'."
