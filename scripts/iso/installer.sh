#!/bin/bash
# GingerOS - Professional System Installer
set -euo pipefail

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Robust sourcing (works in ISO or during dev)
if [ -f "${SCRIPT_DIR}/ui.sh" ]; then
    source "${SCRIPT_DIR}/ui.sh"
    source "${SCRIPT_DIR}/disk.sh"
    source "${SCRIPT_DIR}/bash_config.sh"
else
    source "${SCRIPT_DIR}/../lib/ui.sh"
    source "${SCRIPT_DIR}/../lib/disk.sh"
    source "${SCRIPT_DIR}/../lib/bash_config.sh"
fi

# Handle sudo gracefully
if [ -z "$(command -v sudo 2>/dev/null)" ] || [ "$EUID" == "0" ] || [ "${USER:-}" == "root" ]; then
    sudo() { "$@"; }
fi

# --- DEPENDENCY CHECK ---
REQUIRED_TOOLS=(parted mkfs.ext4 tar lsblk blkid useradd chpasswd grub-install)
MISSING_TOOLS=()
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "\033[0;31mERROR: The following required tools are missing in this environment: ${MISSING_TOOLS[*]}\033[0m"
    echo "This live environment is incomplete. Please ensure make-iso.sh included all essentials."
    exit 1
fi

# Step Configuration
ui_init_dashboard "Preparation" "Formatting" "Extraction" "Hardware Sync" "User Setup" "Bootloader"

# --- DISK SELECTION ---
TARGET_DEV="${1:-}"
if [ -z "$TARGET_DEV" ]; then
    ui_draw_header
    echo -e "${ELECTRIC_BLUE}${BOLD}--- DISK SELECTION ---${NC}"
    echo -e "Available Disks:"
    lsblk -d -n -p -o NAME,SIZE,MODEL | grep -v "sr0"
    echo ""
    ui_input "Enter target disk (e.g. /dev/sda)" TARGET_DEV
fi

if [ -z "$TARGET_DEV" ] || [ ! -b "$TARGET_DEV" ]; then
    ui_error "Device '$TARGET_DEV' is not a valid block device."
fi

# --- USER CREDENTIALS ---
ui_draw_header
echo -e "${ELECTRIC_BLUE}${BOLD}--- USER ACCOUNT SETUP ---${NC}"
ui_input "Desired Username" NEW_USER
ui_password "Password for $NEW_USER" NEW_PASS
ui_password "Root Password" ROOT_PASS

# --- SAFETY WARNING ---
ui_draw_header
echo -e "${RED}${BOLD}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
echo -e "${RED}  WARNING: ALL DATA ON $TARGET_DEV WILL BE WIPED!  ${NC}"
echo -e "${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
ui_confirm "Are you absolutely sure you want to proceed?"

# --- INSTALLATION ---
TARBALL=$(find . -maxdepth 1 -name "gingeros-base-rootfs.tar.gz" | head -n 1)
if [ -z "$TARBALL" ]; then
    ui_draw_header
    echo -e "${RED}${BOLD}ERROR: GingerOS RootFS tarball not found!${NC}"
    echo "This ISO does not contain the system payload (gingeros-base-rootfs.tar.gz)."
    echo "Please ensure you have completed Phase 4 and the finalize-system.sh script"
    echo "successfully before building the ISO."
    exit 1
fi

# Step 0: Prep
ui_step 0
ui_log "Wiping $TARGET_DEV..."
disk_prepare "$TARGET_DEV"
sudo parted -s "$TARGET_DEV" mklabel msdos
sudo parted -s "$TARGET_DEV" mkpart primary ext4 1MiB 100%
sudo parted -s "$TARGET_DEV" set 1 boot on
sleep 2

# Step 1: Format
ui_step 1
PART=$(disk_get_partition "$TARGET_DEV")
ui_log "Formatting $PART..."
sudo mkfs.ext4 -F "$PART" >/dev/null 2>&1

# Step 2: Extract
ui_step 2
MNT="/mnt/gingeros_install"
sudo mkdir -p "$MNT"
sudo mount "$PART" "$MNT"

# Read file count for progress bar
TOTAL_FILES=$(cat "${SCRIPT_DIR}/file_count.txt" 2>/dev/null || echo "10000")
ui_log "Deploying GingerOS files (Total: $TOTAL_FILES)..."

# Run tar with verbose output piped to progress bar
sudo tar --xattrs --acls -C "$MNT" -xvzpf "$TARBALL" | ui_progress_bar "$TOTAL_FILES" "Deploying RootFS"

# Step 3: Sync Hardware
ui_step 3
ui_log "Synchronizing hardware IDs..."
NEW_UUID=$(disk_get_uuid "$PART")
cat << EOF | sudo tee "$MNT/etc/fstab" >/dev/null
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
UUID=$NEW_UUID /               ext4    defaults        1       1
proc           /proc           proc    nosuid,noexec,nodev 0       0
sysfs          /sys            sysfs   nosuid,noexec,nodev 0       0
devpts         /dev/pts        devpts  gid=5,mode=620  0       0
tmpfs          /run            tmpfs   defaults        0       0
devtmpfs       /dev            devtmpfs mode=0755,nosuid 0     0
EOF

# Step 4: User & Init Setup
ui_step 4
ui_log "Creating user accounts and Init config..."
echo "root:$ROOT_PASS" | sudo chroot "$MNT" chpasswd

# FIX: Create /etc/inittab as a FILE, not a directory
sudo rm -rf "$MNT/etc/inittab.d"
sudo rm -f "$MNT/etc/inittab"

# 2. Pre-stage a basic inittab so the first boot works even if installer fails
cat << EOF | sudo tee "$MNT/etc/inittab" >/dev/null
id:3:initdefault:
si::sysinit:/etc/rc.d/init.d/rc S
l3:3:wait:/etc/rc.d/init.d/rc 3
1:2345:respawn:/sbin/getty 38400 tty1
EOF

# User Setup
sudo chroot "$MNT" useradd -m -s /bin/bash "$NEW_USER" || true
echo "$NEW_USER:$NEW_PASS" | sudo chroot "$MNT" chpasswd

# Apply bash config (Note: Ensure write_bash_config uses 'EOF' to avoid syntax errors)
write_bash_config "$MNT/root/.bashrc" "root" "true"
write_bash_config "$MNT/home/$NEW_USER/.bashrc" "$NEW_USER" "false"

# Step 5: Bootloader
ui_step 5
ui_log "Installing GRUB..."
sudo mount --bind /dev "$MNT/dev"
sudo mount --bind /proc "$MNT/proc"
sudo mount --bind /sys "$MNT/sys"

KERNEL_IMG=$(ls "$MNT/boot/vmlinuz-"* 2>/dev/null | head -n 1 | xargs basename || echo "")

# FIX: Generate grub.cfg with rootdelay to prevent unknown-block(0,0)
cat << EOF | sudo tee "$MNT/boot/grub/grub.cfg" >/dev/null
set default=0
set timeout=5
insmod part_msdos
insmod ext2
search --no-floppy --fs-uuid --set=root $NEW_UUID
menuentry 'GingerOS' {
    linux /boot/$KERNEL_IMG root=/dev/sda1 rw rootdelay=1 console=tty0}
EOF

# Install GRUB to MBR
sudo chroot "$MNT" grub-install --target=i386-pc --no-floppy --force "$TARGET_DEV"

# --- FINISH ---
sync # Ensure MBR and files are flushed to disk
sudo umount -l "$MNT/dev" "$MNT/proc" "$MNT/sys" "$MNT" 2>/dev/null || true

ui_draw_header
echo -e "${GREEN}${BOLD}--------------------------------------------------"
echo "    INSTALLATION COMPLETE! ENJOY THE SPEED    "
echo -e "--------------------------------------------------${NC}"
echo -e "\nPlease remove the installation media and reboot.\n"
