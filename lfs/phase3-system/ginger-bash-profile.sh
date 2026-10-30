# GingerOS interactive Bash defaults for login shells.
# Keep all changes inside interactive Bash sessions.
[ -n "${BASH_VERSION:-}" ] || return 0
case $- in *i*) ;; *) return 0 ;; esac

shopt -s progcomp cdspell dirspell checkwinsize histappend
bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
bind 'set completion-map-case on' 2>/dev/null || true

HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
