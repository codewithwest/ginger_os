#!/bin/bash
echo "################################################################################";
echo "#-----------------------7.5. Creating Directories------------------------------#";
echo "################################################################################";
echo;echo;echo;
# Create some root-level directories that are not in the limited set 
# required in the previous chapters by issuing the following command:

mkdir -pv /{boot,home,mnt,opt,srv}
sleep 1;

# Create the required set of subdirectories below the root-level 
# by issuing the following commands:

mkdir -pv /etc/{opt,sysconfig};
sleep 1;
mkdir -pv /lib/firmware;
sleep 1;
mkdir -pv /media/{floppy,cdrom};
sleep 1;
mkdir -pv /usr/{,local/}{include,src};
sleep 1;
mkdir -pv /usr/lib/locale;
sleep 1;
mkdir -pv /usr/local/{bin,lib,sbin};
sleep 1;
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man};
sleep 1;
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo};
sleep 1;
mkdir -pv /usr/{,local/}share/man/man{1..8};
sleep 1;
mkdir -pv /var/{cache,local,log,mail,opt,spool};
sleep 1;
mkdir -pv /var/lib/{color,misc,locate};
sleep 1;

ln -sfv /run /var/run;
sleep 1;
ln -sfv /run/lock /var/lock;
sleep 1;

install -dv -m 0750 /root;
sleep 1;
install -dv -m 1777 /tmp /var/tmp;
echo "################################################################################";
echo "#-----------------------Creating Directories complete--------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 3;

echo "################################################################################";
echo "#------------------7.6. Creating Essential Files and Symlinks------------------#";
echo "################################################################################";
echo;echo;echo;
# Historically, Linux maintained a list of the mounted file systems in the file /etc/mtab.
# Modern kernels maintain this list internally and expose it to the user via the /proc filesystem.
# To satisfy utilities that expect to find /etc/mtab, create the following symbolic link:

ln -sv /proc/self/mounts /etc/mtab;
sleep 1;
# Create a basic /etc/hosts file to be referenced in some test suites, 
# and in one of Perl's configuration files as well:

cat > /etc/hosts << EOF
127.0.0.1  localhost $(hostname)
::1        localhost
EOF

sleep 1;


# In order for user root to be able to login and for the name “root” to be recognized, 
# there must be relevant entries in the /etc/passwd and /etc/group files.

# Create the /etc/passwd file by running the following command:

cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/usr/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/usr/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/usr/bin/false
systemd-network:x:76:76:systemd Network Management:/:/usr/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/usr/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/usr/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
systemd-oom:x:81:81:systemd Out Of Memory Daemon:/:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF

# The actual password for root will be set later.

# Create the /etc/group file by running the following command:

cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
kvm:x:61:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
uuidd:x:80:
systemd-oom:x:81:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF
# The created groups are not part of any standard—they are 
# groups decided on in part by the requirements of the Udev configuration in 
# Chapter 9, and in part by common conventions employed by a number of existing 
# Linux distributions. In addition, some test suites rely on specific users or groups. 
# The Linux Standard Base (LSB, available at https://refspecs.linuxfoundation.org/lsb.shtml)
# only recommends that, besides the group root with a Group ID (GID) of 0, a group bin with a 
# GID of 1 be present. The GID of 5 is widely used for the tty group, and the number 5 is also used 
# in systemd for the devpts filesystem. All other group names and GIDs can be chosen freely by the system 
# administrator since well-written programs do not depend on GID numbers, but rather use the group's name.

# The ID 65534 is used by the kernel for NFS and separate user namespaces for unmapped users 
# and groups (those exist on the NFS server or the parent user namespace, but “do not exist” on the 
# local machine or in the separate namespace). We assign nobody and nogroup to avoid an unnamed ID.
# But other distros may treat this ID differently, so any portable program should not depend on this 
# assignment.

# Some tests in Chapter 8 need a regular user. We add this user here and delete this
# account at the end of that chapter.

echo "tester:x:101:101::/home/tester:/bin/bash" >> /etc/passwd
echo "tester:x:101:" >> /etc/group
install -o tester -d /home/tester

# To remove the “I have no name!” prompt, start a new shell. Since the /etc/passwd and /etc/group 
# files have been created, user name and group name resolution will now work:

exec /usr/bin/bash --login

# The login, agetty, and init programs (and others) use a number of log files to record information 
# such as who was logged into the system and when. However, these programs will not write to the log 
# files if they do not already exist. Initialize the log files and give them proper permissions:

touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

# The /var/log/wtmp file records all logins and logouts. The /var/log/lastlog file records when each 
# user last logged in. The /var/log/faillog file records failed login attempts. The /var/log/btmp file 
# records the bad login attempts.

echo "################################################################################";
echo "#----------------Creating Essential Files and Symlinks complete----------------#";
echo "################################################################################";
echo;echo;echo;
sleep 3;