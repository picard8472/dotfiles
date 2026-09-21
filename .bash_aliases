# Git aliases
alias ls='ls --color=auto -Fh'
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

ans() {
  ansible "$@" | ct
}
runrd() {
  ./run-rd.sh "$@" | ct
}
runcmdrd() {
  ./run-playbook-rd.sh "$@" | ct
}

# Hand off interactive bash shells to zsh.
# Guarded to bash + interactive so scripts and `bash -c` are unaffected,
# and so zsh (which sources this via .zshenv) never loops back into itself.
if [ -n "$BASH_VERSION" ] && [ -t 1 ] && command -v zsh >/dev/null 2>&1; then
  export SHELL="$(command -v zsh)"
  exec zsh
fi
