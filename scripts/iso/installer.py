#!/usr/bin/env python3
import curses
import subprocess
import os
import sys
import time
import threading
import queue

# --- CONFIGURATION ---
ELECTRIC_BLUE = 39
LASER_GREEN = 118
LASER_RED = 196
LASER_YELLOW = 226

class InstallerTUI:
    def __init__(self, stdscr):
        self.stdscr = stdscr
        self.steps = ["Welcome", "Disk Selection", "User Setup", "Confirmation", "Installation"]
        self.data = {
            "target_dev": "",
            "username": "ginger",
            "password": "",
            "root_password": ""
        }
        self.history = []
        self.log_queue = queue.Queue()
        self.install_finished = False
        self.install_success = False
        
        # Setup colors
        curses.start_color()
        curses.use_default_colors()
        curses.init_pair(1, ELECTRIC_BLUE, -1)   # Blue
        curses.init_pair(2, LASER_GREEN, -1)     # Green
        curses.init_pair(3, LASER_RED, -1)       # Red
        curses.init_pair(4, LASER_YELLOW, -1)    # Yellow
        
        curses.curs_set(0) # Hide cursor
        self.stdscr.keypad(True)

    def draw_header(self):
        self.stdscr.clear()
        h, w = self.stdscr.getmaxyx()
        
        logo = [
            "  _____ _                         ____   ____",
            " / ____(_)                       / __ \ / ____|",
            "| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ ",
            "| | |_ | | '_ \ / _` |/ _ \ '__|| |  | |\___ \\",
            "| |__| | | | | | (_| |  __/ |   | |__| |____) |",
            " \_____|_|_| |_|\__, |\___|_|    \____/|_____/ ",
            "                 __/ |",
            "                |___/         Installer v2.0 (Python)"
        ]
        
        for i, line in enumerate(logo):
            if i < h:
                self.stdscr.addstr(i + 1, 2, line[:w-4], curses.color_pair(1) | curses.A_BOLD)
            
        if len(logo) + 2 < h:
            self.stdscr.addstr(len(logo) + 2, 2, "🌶️  GingerOS Linux From Scratch Installation 🌶️"[:w-4], curses.color_pair(2))
        if len(logo) + 3 < h:
            self.stdscr.hline(len(logo) + 3, 2, curses.ACS_HLINE, w - 4)

    def draw_footer(self, info=""):
        h, w = self.stdscr.getmaxyx()
        self.stdscr.hline(h - 3, 2, curses.ACS_HLINE, w - 4)
        nav = "[ENTER] Next  [B] Back  [Q] Quit"
        self.stdscr.addstr(h - 2, 2, nav, curses.A_DIM)
        if info:
            self.stdscr.addstr(h - 2, w - len(info) - 2, info, curses.color_pair(4))

    def get_input(self, prompt, y, x, secret=False, default=""):
        curses.curs_set(1)
        self.stdscr.addstr(y, x, f"▸ {prompt}: ", curses.A_BOLD)
        curses.noecho()
        
        input_str = default
        if default:
            if secret:
                self.stdscr.addstr(y, x + len(prompt) + 4, "*" * len(default))
            else:
                self.stdscr.addstr(y, x + len(prompt) + 4, default)

        while True:
            ch = self.stdscr.getch()
            if ch in [10, 13]: # Enter
                break
            elif ch in [curses.KEY_BACKSPACE, 127, 8]:
                if len(input_str) > 0:
                    input_str = input_str[:-1]
                    self.stdscr.addstr(y, x + len(prompt) + 4 + len(input_str), " ")
                    self.stdscr.move(y, x + len(prompt) + 4 + len(input_str))
            elif ch == 27: # ESC or potential back navigation
                curses.curs_set(0)
                return None
            elif 32 <= ch <= 126:
                input_str += chr(ch)
                if secret:
                    self.stdscr.addstr(y, x + len(prompt) + 4 + len(input_str) - 1, "*")
                else:
                    self.stdscr.addstr(y, x + len(prompt) + 4 + len(input_str) - 1, chr(ch))
        
        curses.curs_set(0)
        return input_str

    def step_welcome(self):
        self.draw_header()
        h, w = self.stdscr.getmaxyx()
        self.stdscr.addstr(12, 4, "Welcome to the GingerOS Professional Installer.", curses.A_BOLD)
        self.stdscr.addstr(14, 4, "This utility will guide you through partitioning your disk,")
        self.stdscr.addstr(15, 4, "extracting the RootFS, and configuring your system environment.")
        self.stdscr.addstr(17, 4, "Press [ENTER] to begin the journey...")
        self.draw_footer()
        
        while True:
            ch = self.stdscr.getch()
            if ch in [10, 13]: return 1
            if ch in [ord('q'), ord('Q')]: sys.exit(0)

    def step_disk_selection(self):
        self.draw_header()
        self.stdscr.addstr(11, 4, "--- DISK SELECTION ---", curses.color_pair(1) | curses.A_BOLD)
        
        try:
            output = subprocess.check_output(["lsblk", "-d", "-n", "-p", "-o", "NAME,SIZE,MODEL"], text=True)
            disks = [line.strip() for line in output.split('\n') if line.strip() and "sr0" not in line and "loop" not in line]
        except:
            disks = ["Error retrieving disks"]

        for i, disk in enumerate(disks):
            self.stdscr.addstr(13 + i, 6, f"{i+1}. {disk}")

        self.draw_footer("Detecting storage...")
        
        target = self.get_input("Target device path (e.g. /dev/sda)", 13 + len(disks) + 2, 4, default=self.data["target_dev"])
        if target is None: return -1
        if target:
            self.data["target_dev"] = target
            return 1
        return 0

    def step_user_setup(self):
        self.draw_header()
        self.stdscr.addstr(11, 4, "--- USER ACCOUNT SETUP ---", curses.color_pair(1) | curses.A_BOLD)
        
        u = self.get_input("Desired Username", 13, 4, default=self.data["username"])
        if u is None: return -1
        self.data["username"] = u
        
        p = self.get_input(f"Password for {self.data['username']}", 15, 4, secret=True)
        if p is None: return -1
        self.data["password"] = p
        
        rp = self.get_input("Root Password", 17, 4, secret=True)
        if rp is None: return -1
        self.data["root_password"] = rp
        
        self.draw_footer()
        return 1

    def step_confirmation(self):
        self.draw_header()
        self.stdscr.addstr(11, 4, "--- CONFIRMATION ---", curses.color_pair(3) | curses.A_BOLD)
        
        self.stdscr.addstr(13, 6, f"Target Disk: {self.data['target_dev']}", curses.color_pair(4))
        self.stdscr.addstr(14, 6, f"Username:    {self.data['username']}")
        self.stdscr.addstr(16, 4, "WARNING: ALL DATA ON THE TARGET DISK WILL BE DESTROYED!", curses.color_pair(3) | curses.A_BOLD)
        self.stdscr.addstr(18, 4, "Type 'YES' to confirm and start installation:")
        
        self.draw_footer("Point of no return")
        
        confirm = self.get_input("Confirm", 19, 4)
        if confirm == "YES":
            return 1
        elif confirm is None:
            return -1
        return 0

    def run_installer_logic(self):
        # This runs in a separate thread
        try:
            self.log_queue.put("Starting Disk Preparation...")
            # We'll call the bash installer script with specific arguments or environment variables
            # to skip the UI parts and just do the work.
            env = os.environ.copy()
            env["TARGET_DEV"] = self.data["target_dev"]
            env["NEW_USER"] = self.data["username"]
            env["NEW_PASS"] = self.data["password"]
            env["ROOT_PASS"] = self.data["root_password"]
            env["GINGER_NON_INTERACTIVE"] = "1"
            
            # For now, let's trigger the bash script in a "silent" mode.
            # We need to make sure installer.sh handles these env vars.
            process = subprocess.Popen(
                ["/bin/bash", "./installer.sh", self.data["target_dev"]],
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True
            )
            
            for line in process.stdout:
                self.log_queue.put(line.strip())
            
            process.wait()
            self.install_success = (process.returncode == 0)
        except Exception as e:
            self.log_queue.put(f"CRITICAL ERROR: {str(e)}")
            self.install_success = False
        finally:
            self.install_finished = True

    def step_installation(self):
        self.draw_header()
        self.stdscr.addstr(11, 4, "--- INSTALLATION IN PROGRESS ---", curses.color_pair(2) | curses.A_BOLD)
        
        h, w = self.stdscr.getmaxyx()
        log_win = curses.newwin(h - 18, w - 8, 13, 4)
        
        # Start logic thread
        threading.Thread(target=self.run_installer_logic, daemon=True).start()
        
        logs = []
        while not self.install_finished:
            try:
                while True:
                    line = self.log_queue.get_nowait()
                    logs.append(line)
                    if len(logs) > h - 20: logs.pop(0)
            except queue.Empty:
                pass
            
            log_win.clear()
            for i, line in enumerate(logs):
                log_win.addstr(i, 0, line[:w-10])
            log_win.refresh()
            
            self.stdscr.addstr(h - 5, 4, f"Status: {'Processing...' if not self.install_finished else 'Finished'}")
            self.stdscr.refresh()
            time.sleep(0.1)
            
        self.draw_header()
        if self.install_success:
            self.stdscr.addstr(12, 4, "INSTALLATION SUCCESSFUL!", curses.color_pair(2) | curses.A_BOLD)
            self.stdscr.addstr(14, 4, "GingerOS has been deployed to your disk.")
            self.stdscr.addstr(15, 4, "Please remove the installation media and reboot.")
        else:
            self.stdscr.addstr(12, 4, "INSTALLATION FAILED!", curses.color_pair(3) | curses.A_BOLD)
            self.stdscr.addstr(14, 4, "Check the logs above for details.")
            
        self.stdscr.addstr(18, 4, "Press [ENTER] to exit...")
        while True:
            ch = self.stdscr.getch()
            if ch in [10, 13]: break
        return 1

    def run(self):
        state = 0
        while state < len(self.steps):
            if state == 0: res = self.step_welcome()
            elif state == 1: res = self.step_disk_selection()
            elif state == 2: res = self.step_user_setup()
            elif state == 3: res = self.step_confirmation()
            elif state == 4: res = self.step_installation()
            
            if res == 1:
                self.history.append(state)
                state += 1
            elif res == -1:
                if self.history:
                    state = self.history.pop()
                else:
                    state = 0 # Can't go back further than welcome
            # if res is 0, we just repeat the current state

def main():
    curses.wrapper(lambda stdscr: InstallerTUI(stdscr).run())

if __name__ == "__main__":
    main()
