import os

# Paths
GINGER_ROOT = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
LOG_DIR = os.path.join(GINGER_ROOT, "logs")
STATE_DIR = os.path.join(GINGER_ROOT, ".build_state")
MASTER_LOG = os.path.join(LOG_DIR, "master.log")

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
  _____ _                         ____   ____
 / ____(_)                       / __ \\ / ____|
| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ 
| | |_ | | '_ \\ / _` |/ _ \\ '__|| |  | |\\___ \\
| |__| | | | | | (_| |  __/ |   | |__| |____) |
 \\_____|_|_| |_|\\__, |\\___|_|    \\____/|_____/ 
                 __/ |                         
                |___/         v1.0 [Automated in Style]
"""
