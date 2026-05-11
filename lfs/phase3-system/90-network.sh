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

# Setup eth0 template (Section 7.5.1)
cat > /etc/sysconfig/ifconfig.eth0 << "EOF"
ONBOOT=yes
IFACE=eth0
SERVICE=ipv4-static
IP=192.168.1.2
GATEWAY=192.168.1.1
PREFIX=24
BROADCAST=192.168.1.255
EOF

# Setup DNS (Section 7.5.2)
cat > /etc/resolv.conf << "EOF"
# Begin /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
# End /etc/resolv.conf
EOF

# Setup hostname (Section 7.5.3)
echo "gingeros" > /etc/hostname

# Customizing the /etc/hosts File (Section 7.5.4)
cat > /etc/hosts << "EOF"
# Begin /etc/hosts

127.0.0.1 localhost.localdomain localhost
127.0.1.1 gingeros.westdynamics.org gingeros
::1       localhost.localdomain localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters

# End /etc/hosts
EOF
mark_built "$PKG_NAME"
