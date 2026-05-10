#!/bin/bash
# GingerOS - Network Configuration
source "/lfs/lib/common.sh"
PKG_NAME="network-config"
check_built "$PKG_NAME" && exit 0
log "INFO" "Configuring networking..."
# Setup loopback
mkdir -pv /etc/sysconfig
cat > /etc/sysconfig/ifconfig.lo << "EOF"
ALL_UP=yes
IFACE=lo
SERVICE=ipv4-static
IP=127.0.0.1
PREFIX=8
EOF
# Setup hostname
echo "gingeros" > /etc/hostname
# Basic /etc/hosts
cat > /etc/hosts << "EOF"
127.0.0.1 localhost.localdomain localhost
::1       localhost.localdomain localhost
EOF
mark_built "$PKG_NAME"
