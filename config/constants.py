import os

# Paths
GINGER_ROOT = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))


# Configuration Parser
def load_ginger_conf():
    conf = {
        "LFS_MOUNT": "/mnt/ginger_lfs",
        "BUILD_TYPE": "image",
        "IMAGE_NAME": "ginger_os.img",
        "IMAGE_SIZE": "12G",
    }
    conf_path = os.path.join(GINGER_ROOT, "ginger.conf")
    if os.path.exists(conf_path):
        with open(conf_path, "r") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    key, value = line.split("=", 1)
                    conf[key.strip()] = value.strip()
    return conf


CONFIG = load_ginger_conf()
GINGER_CONF_PATH = os.path.join(GINGER_ROOT, "ginger.conf")


def update_config(key, value):
    """Update a key=value in ginger.conf, preserving comments and order."""
    path = GINGER_CONF_PATH
    if not os.path.exists(path):
        with open(path, "w") as f:
            f.write(f"# GingerOS Configuration File\n{key}={value}\n")
        CONFIG[key] = value
        return

    with open(path, "r") as f:
        lines = f.readlines()

    found = False
    new_lines = []
    for line in lines:
        stripped = line.strip()
        if stripped and not stripped.startswith("#") and "=" in stripped:
            k, _ = stripped.split("=", 1)
            if k.strip() == key:
                new_lines.append(f"{key}={value}\n")
                found = True
                continue
        new_lines.append(line)

    if not found:
        new_lines.append(f"{key}={value}\n")

    with open(path, "w") as f:
        f.writelines(new_lines)

    CONFIG[key] = value


LOG_DIR = os.path.join(GINGER_ROOT, "logs")
STATE_DIR = os.path.join(GINGER_ROOT, ".build_state")
SOURCES_DIR = os.path.join(GINGER_ROOT, "sources")
MASTER_LOG = os.path.join(LOG_DIR, "master.log")

# Build-specific paths from config
LFS_MOUNT = CONFIG.get("LFS_MOUNT", "/mnt/ginger_lfs")
BUILD_TYPE = CONFIG.get("BUILD_TYPE", "image")
IMAGE_NAME = CONFIG.get("IMAGE_NAME", "ginger_os.img")
IMAGE_SIZE = CONFIG.get("IMAGE_SIZE", "12G")
PARALLEL_PHASE3 = CONFIG.get("PARALLEL_PHASE3", "false")
PARALLEL_WINDOW = int(CONFIG.get("PARALLEL_WINDOW", "4"))

SNAPSHOTS_DIR = os.path.join(GINGER_ROOT, ".snapshots")
os.makedirs(SNAPSHOTS_DIR, exist_ok=True)

# State dir must exist before the engine runs — markers (.built) and telemetry
# live here. It is gitignored, so auto-create it (like SNAPSHOTS_DIR above).
os.makedirs(STATE_DIR, exist_ok=True)

# Steps that auto-snapshot after successful completion (critical recovery points)
SNAPSHOT_AFTER = {
    "10_phase2_system",
    "12_phase3_system",
    "13_kernel",
    "14_finalize",
}

# Bright colors for transparent terminals
LASER_GREEN = "bright_green"
LASER_RED = "bright_red"
LASER_BLUE = "bright_cyan"
ELECTRIC_BLUE = "bright_blue"
GINGER_BLUE = "bright_cyan"
NEON_YELLOW = "bright_yellow"
NEON_MAGENTA = "bright_magenta"
BRIGHT_WHITE = "bright_white"

# ASCII Logo
LOGO = """
   ╔═══════════════════════════════════════════╗
   ║           ██████                          ║
   ║          ██    ██                         ║
   ║         ██      ██    █████   ██████      ║
   ║        ██   ▄▄  ██   ██  ██  ██           ║
   ║        ██  ████ ██  ███████  █████        ║
   ║         ██      ██  ██   ██  ██           ║
   ║          ██    ██   ██   ██  ██           ║
   ║           ██████    ███ ███  ██████        ║
   ║                                             ║
   ║         GingerOS  —  Build System           ║
   ╚═══════════════════════════════════════════╝
"""
