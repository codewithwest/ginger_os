#!/bin/bash
# GingerOS - ISO Builder
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "${SCRIPT_DIR}/../lib/disk.sh"
source "${SCRIPT_DIR}/../lib/bash_config.sh"

GINGER_ROOT="$(cd "${SCRIPT_DIR}/../../" && pwd)"
ISO_DIR="$GINGER_ROOT/iso_work"
ISO_OUTPUT="$GINGER_ROOT/gingeros-installer.iso"
INITRD_WORK="$GINGER_ROOT/initrd_work"

log() {
    local TYPE=$1
    local MSG=$2
    echo "[$(date +'%H:%M:%S')] [$TYPE] $MSG"
}

cleanup() {
    sudo rm -rf "$ISO_DIR" "$INITRD_WORK"
}
trap cleanup EXIT

echo "__GINGER_PKG_MARKER__: Preparation"
cleanup
mkdir -p "$ISO_DIR/boot/grub" "$ISO_DIR/installer"

echo "__GINGER_PKG_MARKER__: Mount LFS Image"
LFS_IMG="$GINGER_ROOT/ginger_os.img"
LFS_ROOTFS="$GINGER_ROOT/gingeros-lfs-rootfs.tar.gz"
CACHED_KERNEL="$GINGER_ROOT/vmlinuz-ginger-cached"

# ── Cache check ────────────────────────────────────────────────────────────
# If the tarball and kernel are already on disk, skip the slow mount+tar step.
# Set FORCE_REBUILD=1 to bypass this cache.
if [ -f "$LFS_ROOTFS" ] && [ -f "$CACHED_KERNEL" ] && [ -z "${FORCE_REBUILD:-}" ]; then
    echo "[INFO] Using cached LFS rootfs: $(ls -lh "$LFS_ROOTFS" | awk '{print $5}')"
    echo "[INFO] Using cached kernel: $CACHED_KERNEL"
    # Purge Ubuntu/build-tree contamination if the cache predates the purge step
    # (subshell with pipefail off: tar gets SIGPIPE once grep -q matches -> exit 141)
    if ( set +o pipefail; tar -tzf "$LFS_ROOTFS" 2>/dev/null | grep -qm1 -E '^\./(sources|usr/lib/x86_64-linux-gnu)(/|$)' ); then
        echo "[INFO] Cached rootfs contains Ubuntu/build contamination; purging..."
        python3 "$SCRIPT_DIR/purge-rootfs.py" "$LFS_ROOTFS" "$LFS_ROOTFS" \
            || echo "[WARN] purge failed; shipping raw rootfs"
    fi
    cp "$LFS_ROOTFS" "$ISO_DIR/installer/gingeros-base-rootfs.tar.gz"
    cp "$CACHED_KERNEL" "$ISO_DIR/boot/vmlinuz"
else
    # ── Full mount + extract ───────────────────────────────────────────────
    if [ ! -f "$LFS_IMG" ]; then
        echo "[ERROR] LFS disk image not found at $LFS_IMG"
        exit 1
    fi

    LFS_MOUNT=$(mktemp -d)
    LOOP_DEV=$(losetup --find --show --partscan "$LFS_IMG")
    echo "[INFO] Loop device: $LOOP_DEV  (partition 1: ${LOOP_DEV}p1)"
    sleep 1
    partprobe "$LOOP_DEV" 2>/dev/null || true
    mount -o ro "${LOOP_DEV}p1" "$LFS_MOUNT"
    echo "[INFO] LFS image mounted at $LFS_MOUNT"

    # Cleanup trap for this block
    trap 'umount "$LFS_MOUNT" 2>/dev/null || true; losetup -d "$LOOP_DEV" 2>/dev/null || true; rmdir "$LFS_MOUNT" 2>/dev/null || true' EXIT

    # Kernel
    KERNEL_IMG=$(ls "$LFS_MOUNT"/boot/vmlinuz* 2>/dev/null | head -n1 || true)
    if [ -z "$KERNEL_IMG" ]; then
        echo "[ERROR] No kernel found in $LFS_MOUNT/boot/"
        ls "$LFS_MOUNT/boot/" || true
        exit 1
    fi
    echo "[INFO] Using LFS kernel: $KERNEL_IMG"
    cp -v "$KERNEL_IMG" "$ISO_DIR/boot/vmlinuz"
    cp -v "$KERNEL_IMG" "$CACHED_KERNEL"    # cache for next run

    # Rootfs tarball
    echo "[INFO] Creating LFS rootfs tarball (this may take a few minutes)..."
    tar -czpf "$LFS_ROOTFS" \
        --one-file-system \
        --exclude="./proc/*" \
        --exclude="./sys/*" \
        --exclude="./dev/*" \
        --exclude="./run/*" \
        --exclude="./tmp/*" \
        --exclude="./sources" \
        --exclude="./lfs" \
        --exclude="./ginger_os" \
        --exclude="./scripts" \
        --exclude="./logs" \
        --exclude="./ccache" \
        --exclude="./tools" \
        --exclude="./usr/lib/x86_64-linux-gnu" \
        --exclude="./lib/x86_64-linux-gnu" \
        --exclude="./etc/apt" \
        --exclude="./etc/dpkg" \
        --exclude="./etc/pam.d" \
        --exclude="./etc/init.d" \
        --exclude="./etc/rc?.d" \
        --exclude="./etc/init" \
        --exclude="./var/lib/apt" \
        --exclude="./var/lib/dpkg" \
        --exclude="./var/cache/apt" \
        --exclude="./var/log/ginger_build" \
        --exclude="./usr/lib/python3.12" \
        -C "$LFS_MOUNT" .
    echo "[INFO] Stripping Ubuntu/build-tree remnants (mtime filter + os-release)..."
    python3 "$SCRIPT_DIR/purge-rootfs.py" "$LFS_ROOTFS" "$LFS_ROOTFS" \
        || echo "[WARN] purge failed; shipping raw rootfs"
    echo "[INFO] LFS rootfs tarball size: $(ls -lh "$LFS_ROOTFS" | awk '{print $5}')"
    cp "$LFS_ROOTFS" "$ISO_DIR/installer/gingeros-base-rootfs.tar.gz"

    umount "$LFS_MOUNT"
    losetup -d "$LOOP_DEV"
    rmdir "$LFS_MOUNT"
    trap 'sudo rm -rf "$ISO_DIR" "$INITRD_WORK"' EXIT
fi

echo "__GINGER_PKG_MARKER__: Initrd"
sudo rm -rf "$INITRD_WORK"

ESSENTIAL_TOOLS=(
    bash sh mount umount mkdir ls cat grep sed awk rm
    parted partprobe mkfs.ext4 tar lsblk blkid wipefs gzip udevadm
    grub-install tee sleep which clear ps kill tput
    readlink dirname touch du df
    head tail sort uniq date wc tr cut xargs cp mv ln rm mv
    chmod chown env find losetup fuser locale reboot poweroff chroot
    mktemp sync dd false true test install
)

# Create essential system directory structure
mkdir -p "$INITRD_WORK"/{bin,dev,etc,lib,lib64,mnt,proc,run,sys,tmp,var,root,usr}

# Create merged usr compatibility symlinks and standard layout
ln -sf bin "$INITRD_WORK/sbin"
ln -sf ../bin "$INITRD_WORK/usr/bin"
ln -sf ../bin "$INITRD_WORK/usr/sbin"
# Function to copy binary and its dependencies
copy_exe() {
    local exe=$1
    local dest=$2
    local binary_path=$(which "$exe")
    
    if [ -z "$binary_path" ]; then
        log "WARN" "Binary $exe not found, skipping."
        return
    fi
    
    # Copy the binary
    cp "$binary_path" "$dest/bin/"
    
    # Copy its libraries (dereference: plain cp would copy a dangling symlink)
    ldd "$binary_path" | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp -vL '{}' "$dest/lib/x86_64-linux-gnu/" 2>/dev/null || true
    # Also copy the loader if present
    ldd "$binary_path" | grep "/lib64/" | awk '{print $1}' | xargs -I '{}' cp -v '{}' "$dest/lib64/" 2>/dev/null || true
}

log "INFO" "Preparing tool binaries..."
mkdir -p "$INITRD_WORK/bin" "$INITRD_WORK/lib/x86_64-linux-gnu" "$INITRD_WORK/lib64"
for tool in "${ESSENTIAL_TOOLS[@]}"; do
    copy_exe "$tool" "$INITRD_WORK"
done
ln -sf ../lib "$INITRD_WORK/usr/lib"
ln -sf ../lib64 "$INITRD_WORK/usr/lib64"

for tool in "${ESSENTIAL_TOOLS[@]}"; do
    # Use 'type -P' to find the executable path, ignoring shell builtins and aliases
    TOOL_PATH=$(type -P "$tool" || true)
    
    if [ -z "$TOOL_PATH" ]; then
        echo "[WARN] Missing tool '$tool' (or only available as builtin), skipping"
        continue
    fi
    
    cp -vL "$TOOL_PATH" "$INITRD_WORK/bin/"
done

echo "[INFO] Resolving library dependencies..."
for file in "$INITRD_WORK/bin/"*; do
    # Check if file exists (in case glob matches nothing)
    [ -e "$file" ] || continue
    
    # Skip if not an executable or is a directory
    [ -f "$file" ] || continue

    # Get libraries, ignoring errors (e.g. if file is a script or static binary)
    # properly handle pipefail: ensure command doesn't fail if grep finds nothing
    LIBS=$(ldd "$file" 2>/dev/null | awk '{print $3}' | grep '^/' || true)

    if [ -n "$LIBS" ]; then
        echo "  - Dependencies for $(basename "$file")"
        echo "$LIBS" | while read -r lib; do
            dest="$INITRD_WORK$(dirname "$lib")"
            if [ ! -d "$dest" ]; then
                mkdir -p "$dest"
            fi
            cp -fL "$lib" "$dest/" 2>/dev/null || true
        done
    fi
done

# Dynamic linker
if [ -f /lib64/ld-linux-x86-64.so.2 ]; then
    mkdir -p "$INITRD_WORK/lib64"
    cp -L /lib64/ld-linux-x86-64.so.2 "$INITRD_WORK/lib64/"
fi

# Copy Go installer binary (single static binary, no runtime deps)
cp "$GINGER_ROOT/lfs/iso/ginger-installer" "$ISO_DIR/installer/ginger-installer"
cp "$GINGER_ROOT/lfs/iso/installer.sh" "$ISO_DIR/installer/"
cp "$GINGER_ROOT/lfs/lib/disk.sh" "$ISO_DIR/installer/"
cp "$GINGER_ROOT/lfs/lib/bash_config.sh" "$ISO_DIR/installer/"
cp "$GINGER_ROOT/ginger.conf" "$ISO_DIR/installer/" 2>/dev/null || true

# Copy GRUB modules (Essential for grub-install)
if [ -d /usr/lib/grub ]; then
    echo "[INFO] Copying GRUB modules..."
    mkdir -p "$INITRD_WORK/usr/lib"
    cp -r /usr/lib/grub "$INITRD_WORK/usr/lib/"
fi

# Copy Terminfo (Fixes "terminals database is inaccessible")
if [ -d /usr/share/terminfo ]; then
    echo "[INFO] Copying terminfo..."
    mkdir -p "$INITRD_WORK/usr/share"
    cp -r /usr/share/terminfo "$INITRD_WORK/usr/share/"
elif [ -d /lib/terminfo ]; then
     echo "[INFO] Copying terminfo from /lib..."
     mkdir -p "$INITRD_WORK/lib"
     cp -r /lib/terminfo "$INITRD_WORK/lib/"
fi

# Go installer binary is statically linked — no Python/runtime bundling needed


# Init script
cat << 'EOF' > "$INITRD_WORK/init"
#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

echo "=== GingerOS Installer Boot ==="

mount -t proc proc /proc || true
mount -t sysfs sysfs /sys || true
mount -t devtmpfs devtmpfs /dev || true

# PID 1 must never exit: a dying init panics the kernel. Everything below
# loops forever; failures drop to a recovery shell and then retry.
while true; do
    mkdir -p /mnt/iso

    FOUND_ISO=
    if [ -f /mnt/iso/installer/installer.sh ]; then
        FOUND_ISO="mounted"
    else
        # Find ISO
        for dev in /dev/sr0 /dev/vda /dev/sda /dev/sdb /dev/sdc; do
            if [ -b "$dev" ]; then
                if mount -o ro "$dev" /mnt/iso 2>/dev/null; then
                    if [ -f /mnt/iso/installer/installer.sh ]; then
                        FOUND_ISO="$dev"
                        echo "Found GingerOS ISO on $dev"
                        break
                    fi
                    umount /mnt/iso 2>/dev/null
                fi
            fi
        done
    fi

    if [ -n "$FOUND_ISO" ]; then
        cd /mnt/iso/installer
        # Launch Go installer (single static binary, no runtime deps)
        if ./ginger-installer; then
            echo "Installation process has concluded."
            echo "Press [R] to Reboot or [S] for Shell"
            while true; do
                read -r ACTION || { sleep 1; continue; }
                case "$ACTION" in
                    [Rr]*) /bin/reboot -f ;;
                    [Ss]*) /bin/sh ;;
                    *)     echo "Press [R] to Reboot or [S] for Shell" ;;
                esac
            done
        else
            rc=$?
            echo "ERROR: Go installer failed (exit $rc)."
            echo "Debug log: /tmp/ginger-install.log"
            echo "Starting recovery shell. Type 'exit' to retry the installer."
            /bin/sh || true
        fi
    else
        echo "ERROR: GingerOS ISO not found."
        echo "Starting recovery shell. Type 'exit' to retry."
        /bin/sh || true
    fi
done
EOF
chmod +x "$INITRD_WORK/init"

(cd "$INITRD_WORK" && find . | cpio -o -H newc | gzip -c > "$ISO_DIR/boot/initrd.img")

cat << EOF > "$ISO_DIR/boot/grub/grub.cfg"
set default=0
set timeout=5

menuentry "Install GingerOS" {
    linux /boot/vmlinuz root=/dev/ram0 rw console=ttyS0 console=tty0 loglevel=7
    initrd /boot/initrd.img
}
EOF

grub-mkrescue -o "$ISO_OUTPUT" "$ISO_DIR"
echo "SUCCESS! ISO created at: $ISO_OUTPUT"