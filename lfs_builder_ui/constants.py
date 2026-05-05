import os

# Paths
GINGER_ROOT = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))

# Configuration Parser
def load_ginger_conf():
    conf = {
        "LFS_MOUNT": "/mnt/lfs",
        "BUILD_TYPE": "image",
        "IMAGE_NAME": "ginger_os.img",
        "IMAGE_SIZE": "12G"
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

LOG_DIR = os.path.join(GINGER_ROOT, "logs")
STATE_DIR = os.path.join(GINGER_ROOT, ".build_state")
SOURCES_DIR = os.path.join(GINGER_ROOT, "sources")
MASTER_LOG = os.path.join(LOG_DIR, "master.log")

# Build-specific paths from config
LFS_MOUNT = CONFIG.get("LFS_MOUNT", "/mnt/lfs")
BUILD_TYPE = CONFIG.get("BUILD_TYPE", "image")
IMAGE_NAME = CONFIG.get("IMAGE_NAME", "ginger_os.img")
IMAGE_SIZE = CONFIG.get("IMAGE_SIZE", "12G")

# Create directories
os.makedirs(LOG_DIR, exist_ok=True)
os.makedirs(STATE_DIR, exist_ok=True)

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
  _____ _                         ____   ______
 / ____(_)                       / __ \\ / ____|
| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ 
| | |_ | | '_ \\ / _` |/ _ \\ '__|| |  | |\\___ \\
| |__| | | | | | (_| |  __/ |   | |__| |____) |
 \\_____|_|_| |_|\\__, |\\___|_|    \\____/|_____/ 
                 __/ |                         
                |___/         v1.0.0 [Automated in Style]
"""
