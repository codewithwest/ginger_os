#!/bin/bash
# LFS 12.4 - 8.83. Sysklogd-2.7.2
source "/scripts/common.sh"
PKG_NAME="sysklogd"
ARCHIVE="sysklogd-2.7.2.tar.gz"
DIR_NAME="sysklogd-2.7.2"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr --sysconfdir=/etc
make $MAKEFLAGS
make install
cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf
auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *
# End /etc/syslog.conf
EOF
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
