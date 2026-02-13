import os

GINGER_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE_DIR = os.path.join(GINGER_ROOT, ".build_state")
LOG_DIR = os.path.join(GINGER_ROOT, "logs")
MASTER_LOG = os.path.join(STATE_DIR, "ginger_os_build.log")

# Create directories
os.makedirs(STATE_DIR, exist_ok=True)
os.makedirs(LOG_DIR, exist_ok=True)

# Colors & Style
ELECTRIC_BLUE = "#268bd2"
LASER_GREEN = "#859900"
LASER_RED = "#dc322f"
LASER_YELLOW = "#b58900"

# ASCII Logo
LOGO = """
  _____ _                         ____   ____
 / ____(_)                       / __ \\ / ____|
| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ 
| | |_ | | '_ \\ / _` |/ _ \\ '__|| |  | |\\___ \\
| |__| | | | | | (_| |  __/ |   | |__| |____) |
 \\_____|_|_| |_|\\__, |\\___|_|    \\____/|_____/ 
                 __/ |                         
                |___/         v1.0 [Python]
"""
