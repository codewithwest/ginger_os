#!/usr/bin/env python3
"""Streaming purge of Ubuntu/build-tree contamination from the GingerOS LFS rootfs tarball."""
import sys
import tarfile
import os.path

SRC = sys.argv[1] if len(sys.argv) > 1 else "/home/west/Documents/github/ginger/ginger_os/gingeros-lfs-rootfs.tar.gz"
DST = sys.argv[2] if len(sys.argv) > 2 else "/tmp/opencode/gingeros-lfs-rootfs-pure.tar.gz"
INPLACE = os.path.abspath(SRC) == os.path.abspath(DST)

PATH_DROP_PREFIXES = [
    # Ubuntu multilib trees
    "usr/lib/x86_64-linux-gnu/",
    "lib/x86_64-linux-gnu/",
    # apt/dpkg
    "etc/apt/", "etc/dpkg/",
    "var/lib/apt/", "var/lib/dpkg/", "var/cache/apt/",
    "usr/lib/apt/", "usr/lib/dpkg/",
    # pam / sysvinit / upstart (Ubuntu)
    "etc/pam.d/", "etc/init.d/", "etc/rc", "etc/init/",
    # python dist-packages / ubuntu-advantage
    "usr/lib/python3.12/", "usr/lib/ubuntu-advantage/", "usr/share/ubuntu-advantage/",
    "usr/share/doc/python3.12/",
    # build-tree junk baked into $LFS (dir entries + contents)
    "sources", "lfs", "ginger_os", "scripts", "logs", "ccache", "tools",
    # build logs
    "var/log/ginger_build/",
]

PATH_DROP_EXACT = {
    # tzdata source files unpacked at rootfs root
    "africa", "antarctica", "asia", "australasia", "backward", "backzone",
    "calendars", "etcetera", "europe", "factory", "iso3166.tab",
    "leap-seconds.list", "leapseconds", "leapseconds.awk",
    "northamerica", "southamerica", "zone.tab", "zone1970.tab", "zonenow.tab",
    "ziguard.awk", "zishrink.awk", "checktab.awk", "checknow.awk", "checklinks.awk", "theory.html",
    # build/upstream junk at root
    "config", "Makefile", "NEWS", "README", "SECURITY", "LICENSE", "CONTRIBUTING",
    "version",
    # debootstrap merged-usr markers
    "bin.usr-is-merged", "lib.usr-is-merged", "sbin.usr-is-merged",
    # Ubuntu os-release (we inject an LFS-branded one below)
    "etc/os-release", "usr/lib/os-release",
    # Ubuntu logs
    "var/log/dpkg.log", "var/log/alternatives.log", "var/log/bootstrap.log",
    "var/log/debootstrap.log", "var/log/aptitude", "var/log/faillog",
}

MTIME_DIRS = ("usr/bin/", "usr/sbin/", "usr/lib/", "usr/libexec/")

# Legit LFS-installed files that upstream ships with old source mtimes.
# meson's configure_file preserves the .in source file's mtime, so these
# survive our 2026 ninja install untouched; the mtime filter below must not
# purge them as "Ubuntu contamination" or systemd/dbus break at boot.
KEEP_EXACT = {
    "usr/lib/systemd/system/dbus.service",
    "usr/lib/systemd/system/dbus.socket",
    "usr/lib/systemd/system/sockets.target.wants/dbus.socket",
    "usr/lib/systemd/system/multi-user.target.wants/dbus.service",
    "usr/lib/tmpfiles.d/dbus.conf",
    "usr/lib/sysusers.d/dbus.conf",
}

def drop(m):
    p = m.name.lstrip("./")
    if not p:
        return False
    if p in KEEP_EXACT:
        return False
    if p in PATH_DROP_EXACT:
        return True
    for pre in PATH_DROP_PREFIXES:
        if p.startswith(pre) or p == pre.rstrip("/"):
            return True
    if m.isfile() or m.islnk() or m.issym():
        if any(p.startswith(d) for d in MTIME_DIRS):
            y = m.mtime and __import__("time").localtime(m.mtime).tm_year
            if y is not None and y < 2026:
                return True
    return False

OS_RELEASE = b'''NAME="GingerOS"
VERSION="1.0"
ID=gingeros
ID_LIKE="lfs"
PRETTY_NAME="GingerOS 1.0"
VERSION_ID="1.0"
HOME_URL=""
'''

def inject_os_release(dst):
    import io
    ti = tarfile.TarInfo("etc/os-release")
    ti.size = len(OS_RELEASE)
    ti.mode = 0o644
    ti.mtime = int(__import__("time").time())
    dst.addfile(ti, io.BytesIO(OS_RELEASE))

def main():
    dropped = kept = 0
    droplist = []
    out = DST + ".tmp" if INPLACE else DST
    with tarfile.open(SRC, "r:gz") as src, tarfile.open(out, "w:gz", compresslevel=1) as dst:
        for m in src:
            if drop(m):
                dropped += 1
                if len(droplist) < 60:
                    droplist.append(m.name)
                continue
            if m.isfile():
                f = src.extractfile(m)
                if f is None:
                    continue
                dst.addfile(m, f)
            else:
                dst.addfile(m)
            kept += 1
        inject_os_release(dst)
    if INPLACE:
        os.replace(out, DST)
    print(f"kept={kept} dropped={dropped}")
    print("sample dropped:")
    for n in droplist:
        print("  ", n)

if __name__ == "__main__":
    main()
