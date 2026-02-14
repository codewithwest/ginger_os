#!/bin/bash
# GingerOS - Professional Bash Configuration Template

write_bash_config() {
    local TARGET_FILE=$1
    local USERNAME=$2
    local IS_ROOT=$3
    
    # GingerOS Brand Colors (ANSI)
    local ELECTRIC_BLUE='\[\033[38;5;39m\]'
    local LASER_GREEN='\[\033[38;5;118m\]'
    local LASER_RED='\[\033[38;5;196m\]'
    local LASER_YELLOW='\[\033[38;5;226m\]'
    local BOLD='\[\033[1m\]'
    local NC='\[\033[0m\]'

    local PROMPT_COLOR="$LASER_GREEN"
    [[ "$IS_ROOT" == "true" ]] && PROMPT_COLOR="$LASER_RED"

    cat << EOF > "$TARGET_FILE"
# GingerOS west Bash Configuration
# System-wide settings for $USERNAME

export TERM=xterm-256color
export EDITOR=nano
export VISUAL=nano

# Colors
BLUE='$ELECTRIC_BLUE'
GREEN='$LASER_GREEN'
RED='$LASER_RED'
YELLOW='$LASER_YELLOW'
BOLD='$BOLD'
NC='$NC'

# Git helper functions for prompt/aliases
git_main_branch() {
  command git rev-parse --git-dir &>/dev/null || return
  local ref
  for ref in refs/heads/main refs/heads/master refs/remotes/origin/main refs/remotes/origin/master; do
    if command git show-ref -q --verify "\$ref"; then
      echo "\${ref##*/}"
      return
    fi
  done
  echo master
}

git_current_branch() {
  command git rev-parse --abbrev-ref HEAD 2> /dev/null
}

# Prompt setup
if [ "\$EUID" -eq 0 ]; then
    PS1="\${RED}\${BOLD}root@gingeros\${NC}:\${BLUE}\w\${NC}# "
else
    PS1="\${GREEN}\${BOLD}\u@gingeros\${NC}:\${BLUE}\w\${NC}\$ "
fi

# General Aliases
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias install-os='sudo bash /installer/installer.sh'
alias _='sudo '
alias md='mkdir -p'
alias rd='rmdir'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias -='cd -'

# Git Aliases (Standard)
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gap='git add --patch'
alias gau='git add --update'
alias gav='git add --verbose'
alias gb='git branch'
alias gba='git branch --all'
alias gbd='git branch --delete'
alias gbD='git branch --delete --force'
alias gbl='git blame -w'
alias gbm='git branch --move'
alias gbr='git branch --remote'
alias gbs='git bisect'
alias gbsb='git bisect bad'
alias gbsg='git bisect good'
alias gbsr='git bisect reset'
alias gbss='git bisect start'
alias gc='git commit --verbose'
alias 'gc!'='git commit --verbose --amend'
alias gca='git commit --verbose --all'
alias 'gca!'='git commit --verbose --all --amend'
alias gcam='git commit --all --message'
alias gcas='git commit --all --signoff'
alias gcb='git checkout -b'
alias gcl='git clone --recurse-submodules'
alias gclean='git clean --interactive -d'
alias gco='git checkout'
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpc='git cherry-pick --continue'
alias gd='git diff'
alias gdca='git diff --cached'
alias gds='git diff --staged'
alias gdw='git diff --word-diff'
alias gf='git fetch'
alias gfa='git fetch --all --tags --prune --jobs=10'
alias gfo='git fetch origin'
alias gl='git pull'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias gm='git merge'
alias gma='git merge --abort'
alias gmc='git merge --continue'
alias gmff='git merge --ff-only'
alias gp='git push'
alias gpd='git push --dry-run'
alias gpf='git push --force-with-lease --force-if-includes'
alias 'gpf!'='git push --force'
alias gpr='git pull --rebase'
alias gpsup='git push --set-upstream origin \$(git_current_branch)'
alias gr='git remote'
alias gra='git remote add'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbi='git rebase --interactive'
alias grev='git revert'
alias grh='git reset'
alias grhh='git reset --hard'
alias grm='git rm'
alias grmc='git rm --cached'
alias grs='git restore'
alias grst='git restore --staged'
alias gst='git status'
alias gss='git status --short'
alias gsta='git stash push'
alias gstaa='git stash apply'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gsu='git submodule update'
alias gsw='git switch'
alias gswc='git switch --create'

# Advanced Git Aliases
alias grt='cd "\$(git rev-parse --show-toplevel || echo .)"'
alias gwip='git add -A; git rm \$(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"'
alias gunwip='git rev-list --max-count=1 --format="%s" HEAD | grep -q "\--wip--" && git reset HEAD~1'

# Docker Aliases
alias dps='docker ps'
alias dcu='docker compose up'
alias dcd='docker compose down'
alias dei='docker exec -it'
alias di='docker inspect'
alias dip='docker image prune'
alias dbp='docker builder prune'
alias dcp='docker container prune'

# System Aliases
alias history='history'
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Directory Aliases
alias docs='cd ~/Documents'
alias downs='cd ~/Downloads'
alias www='cd ~/www/html'

# Functions
tarunzip() { tar -xzvf "$1"; }
tarzip() { tar -czvf "$1.tar.gz" "$2"; }

# Branding
if [ -f /etc/ginger_issue ]; then
    cat /etc/ginger_issue
fi

echo -e "\${BLUE}Welcome to GingerOS ${USERNAME} Edition\${NC}"
EOF
}
