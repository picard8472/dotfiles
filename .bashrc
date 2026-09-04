# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# Better console colors for files and directories
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced

# User specific aliases and functions
export EDITOR="vim"

# Git aliases
alias ls='ls -GFh'
alias ll='ls -la'
alias gs='git status -s'
alias ga='git add'
alias gc='git commit --verbose'
alias gca='git commit -a --verbose'
alias gd='git diff'
alias gds='git diff --stat'
alias gl='git log --pretty=format:"%C(yellow)%h\\ %ad%Cred%d\\ %Creset%s%Cblue\\ [%cn]" --decorate --date=short'
alias gpl='git pull'
alias gplm='git pull --tags origin main'
alias gps='git push'

# Persist shell history across workspace rebuilds
export HISTFILE=/persistent/.bash_history   # use /workspaces if on hydrant or a no-/persistent template
export HISTSIZE=100000
export HISTFILESIZE=200000
shopt -s histappend
export PROMPT_COMMAND="history -a; ${PROMPT_COMMAND:-}"

export PATH