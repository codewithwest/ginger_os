#!/bin/bash
# GingerOS - Professional Bash Configuration Template

write_bash_config() {
    local TARGET_FILE=$1
    local USERNAME=$2
    local IS_ROOT=$3
    
    local PROMPT_COLOR='${LASER_GREEN}'
    [[ "$IS_ROOT" == "true" ]] && PROMPT_COLOR='${RED}'

    cat << EOF > "$TARGET_FILE"
# GingerOS Cyberpunk Bash Config
export TERM=xterm-256color

# Colors
BLUE='\[\033[38;5;39m\]'
GREEN='\[\033[38;5;118m\]'
RED='\[\033[0;31m\]'
NC='\[\033[0m\]'
BOLD='\[\033[1m\]'

# Prompt
if [ "\$EUID" -eq 0 ]; then
    PS1="\${RED}\${BOLD}root@gingeros\${NC}:\${BLUE}\w\${NC}# "
else
    PS1="\${GREEN}\${BOLD}\u@gingeros\${NC}:\${BLUE}\w\${NC}\$ "
fi

# Aliases
alias ls='ls --color=auto'
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias install-os='sudo bash /installer/installer.sh'

# Branding
if [ -f /etc/ginger_issue ]; then
    cat /etc/ginger_issue
fi

echo -e "\${BLUE}Welcome to GingerOS Cyberpunk Edition\${NC}"
EOF
}
