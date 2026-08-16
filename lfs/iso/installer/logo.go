package main

const logo = "      _                            \n" +
	" __ _(_)_ _  __ _ ___ _ _   ___ ___\n" +
	"/ _` | | ' \\/ _` / -_) '_| / _ (_-<\n" +
	"\\__, |_|_||_\\__, \\___|_|   \\___/__/\n" +
	"|___/       |___/                  "

// Installer version reported on the welcome screen. Bump when the
// installer workflow changes.
const installerVersion = "1.1.0"

var stepTitles = []string{
	"Welcome",
	"Partitioning",
	"Extract Filesystem",
	"Hardware Sync",
	"User Setup",
	"Bootloader",
}

var spinnerFrames = []string{"┤", "┘", "┴", "└", "├", "┌", "┬", "┐"}
