#!/bin/bash
# LFS 12.4 - 8.83. Sysklogd-2.7.2
source "$(dirname "$(readlink -f "$0")")/common.sh"
PKG_NAME="sysklogd"
check_built "$PKG_NAME" && exit 0
extract "sysklogd"
./configure --prefix=/usr --sysconfdir=/etc
make $MAKEFLAGS
make install

cat > /etc/syslog.conf << "EOF"
auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/syslog.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *
EOF

cd .. && rm -rf "sysklogd-"*
mark_built "$PKG_NAME"
# Note: Root required for syslog install.
