#!/bin/bash
# GingerOS - Network Configuration (systemd/netplan style)
source "/lfs/lib/common.sh"
PKG_NAME="network-config"
check_built "$PKG_NAME" && exit 0
log "INFO" "Configuring networking for systemd networkd..."

mkdir -pv /etc/systemd/network
cat > /etc/systemd/network/20-dhcp.network << "EOF"
[Match]
Name=en* eth* ens* eno* wlp* wlan*

[Network]
DHCP=ipv4
EOF

# Setup hostname
echo "gingeros" > /etc/hostname

# Customize /etc/hosts
cat > /etc/hosts << "EOF"
# Begin /etc/hosts
127.0.0.1 localhost.localdomain localhost
127.0.1.1 gingeros.westdynamics.org gingeros
::1       localhost.localdomain localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
# End /etc/hosts
EOF

# Setup DNS resolver
cat > /etc/resolv.conf << "EOF"
# Begin /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
# End /etc/resolv.conf
EOF

mark_built "$PKG_NAME"
