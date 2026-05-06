#!/bin/bash
set -e

echo "Cleaning GingerOS base image..."

# Remove temp files
rm -rf /tmp/*
rm -rf /var/tmp/*

# Clear logs
find /var/log -type f -exec truncate -s 0 {} \;

# Remove SSH host keys (regenerated on first boot later)
rm -f /etc/ssh/ssh_host_*

# Clear machine identity (for future dbus/systemd style tools)
rm -f /etc/machine-id 2>/dev/null || true

# Remove bash history
rm -f /root/.bash_history

echo "GingerOS base image finalized."
