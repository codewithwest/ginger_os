#!/bin/bash
# GingerOS - System V Boot Configuration (LFS 12.4 - Section 7.6)
source "/lfs/lib/common.sh"
PKG_NAME="boot-config"
check_built "$PKG_NAME" && exit 0

log "INFO" "Configuring System V bootscripts (clock, console, etc.)..."

# 7.6.4. Configuring the System Clock
cat > /etc/sysconfig/clock << "EOF"
# Begin /etc/sysconfig/clock
UTC=1
# Set this to any options you might need to give to hwclock,
# such as machine hardware clock type for Alphas.
CLOCKPARAMS=
# End /etc/sysconfig/clock
EOF

# 7.6.5. Configuring the Linux Console
cat > /etc/sysconfig/console << "EOF"
# Begin /etc/sysconfig/console
# Default US layout
KEYMAP="us"
FONT="lat1-16 -m 8859-1"
UNICODE="1"
LOGLEVEL="7"
# End /etc/sysconfig/console
EOF

# 7.6.6. Creating Files at Boot (Template)
cat > /etc/sysconfig/createfiles << "EOF"
# /etc/sysconfig/createfiles
# This file contains a list of files/directories to be created at boot.
# Format: <type> <name> <mode> <uid> <gid>
# type: d=directory, f=file, s=symlink
EOF

# 7.6.8. The rc.site File
cat > /etc/sysconfig/rc.site << "EOF"
# /etc/sysconfig/rc.site
# Optional parameters for boot scripts.

DISTRO="GingerOS"
DISTRO_CONTACT="west@gingeros.org"
DISTRO_MINI="GINGER"

# Use colored messages
BRACKET="\\033[1;34m" # Blue
FAILURE="\\033[1;31m" # Red
INFO="\\033[1;36m"    # Cyan
NORMAL="\\033[0;39m"  # Grey
SUCCESS="\\033[1;32m" # Green
WARNING="\\033[1;33m" # Yellow

# Speed up boot
OMIT_UDEV_SETTLE=y
OMIT_UDEV_RETRY_SETTLE=yes
SKIPTMPCLEAN=no

# General settings
UTC=1
HOSTNAME="gingeros"

# Optional sysklogd parameters (Section 7.6.7)
SYSKLOGD_PARMS="-m 0"

# Console parameters (Section 7.6.5)
UNICODE=1
KEYMAP="us"
FONT="lat1-16 -m 8859-1"
EOF

# 7.4.3. Dealing with duplicate devices (Template)
cat > /etc/udev/rules.d/83-duplicate_devs.rules << "EOF"
# Persistent symlinks for duplicate devices (e.g. webcams, tuners)
# Figure out attributes with: udevadm info -a -p /sys/class/video4linux/video0
# KERNEL=="video*", ATTRS{idProduct}=="1910", ATTRS{idVendor}=="0d81", SYMLINK+="webcam"
EOF

mark_built "$PKG_NAME"
