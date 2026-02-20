#!/usr/bin/env bash
set -euo pipefail

TARGET_DEV="${1:-}"
if [ -z "$TARGET_DEV" ]; then
  echo "Usage: $0 /dev/sdX"
  exit 1
fi

MNT="/mnt/ginger"
ROOT_PART="${TARGET_DEV}1"

echo "[INFO] Installing GingerOS to $TARGET_DEV"

# Partition (MBR)
echo "[INFO] Partitioning disk..."
# Wipe existing signatures to prevent UUID confusion
wipefs -a "$TARGET_DEV" || true
parted -s "$TARGET_DEV" mklabel msdos
parted -s "$TARGET_DEV" mkpart primary ext4 1MiB 100%
partprobe "$TARGET_DEV"
udevadm settle
sleep 2

# Format
echo "[INFO] Formatting root partition..."
mkfs.ext4 -F "$ROOT_PART"

# Re-read UUID to ensure we get the new one
partprobe "$TARGET_DEV"
udevadm settle
sleep 2

# Mount
mkdir -p "$MNT"
mount "$ROOT_PART" "$MNT"

# Copy rootfs
echo "[INFO] Copying root filesystem..."
tar -xpf /mnt/iso/installer/gingeros-base-rootfs.tar.gz -C "$MNT"

# Install kernel
echo "[INFO] Installing kernel..."
mkdir -p "$MNT/boot"
cp /mnt/iso/boot/vmlinuz "$MNT/boot/vmlinuz-ginger"

# Wait for device nodes and UUIDs
udevadm settle
sleep 1

# Robust UUID detection
echo "[INFO] Detecting UUID..."
ROOT_UUID=""
for i in {1..5}; do
    ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
    if [ -n "$ROOT_UUID" ]; then
        break
    fi
    echo "[WARN] Retrying UUID detection ($i/5)..."
    sleep 1
done

if [ -z "$ROOT_UUID" ]; then
    # Fallback to lsblk if blkid fails
    ROOT_UUID=$(lsblk -no UUID "$ROOT_PART" | head -n1)
fi

if [ -z "$ROOT_UUID" ]; then
  echo "[ERROR] Failed to detect UUID for $ROOT_PART"
  exit 1
fi
echo "[INFO] Detected Root UUID: $ROOT_UUID"

# Prepare chroot mounts for GRUB
echo "[INFO] Installing GRUB..."
mount --bind /dev  "$MNT/dev"
mount --bind /proc "$MNT/proc"
mount --bind /sys  "$MNT/sys"

grub-install --target=i386-pc --boot-directory="$MNT/boot" "$TARGET_DEV"

# Write GRUB config (terminal debug)
mkdir -p "$MNT/boot/grub"

cat << EOF > "$MNT/boot/grub/grub.cfg"
set default=0
set timeout=3

terminal_input console
terminal_output console

menuentry 'GingerOS Debug Boot' {
    linux /boot/vmlinuz-ginger \
      root=UUID=$ROOT_UUID \
      rw rootwait rootdelay=10 \
      console=tty0 console=ttyS0,115200 \
      loglevel=7 debug earlyprintk=serial
}

menuentry 'GingerOS Emergency Shell' {
    linux /boot/vmlinuz-ginger \
      root=UUID=$ROOT_UUID \
      rw rootwait rootdelay=10 \
      console=tty0 console=ttyS0,115200 \
      init=/bin/sh \
      loglevel=7 debug earlyprintk=serial
}
EOF

sync
echo "[OK] Installation complete."
echo "You can now reboot into GingerOS."