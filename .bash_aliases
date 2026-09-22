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

prep_env() {
  echo "Prep started..."

  cd "$HOME" || return 1
  mkdir -p git
  cd git || return 1

  gh api --paginate \
    -H "Accept: application/vnd.github+json" \
    'search/commits?q=author:@me+org:rpcpool' \
    --jq '.items[].repository.full_name' |
    sort -u |
    while read -r repo; do
      dir="${repo##*/}"

      if [[ -d "$dir" ]]; then
        echo "Already exists: $repo"
      else
        echo "Cloning: $repo"
        gh repo clone "$repo"
      fi
    done

  cd - >/dev/null || return 1
  echo "Prep done."
}

# Set zsh as the login shell once — no-op after it's set, never blocks or errors.
if command -v zsh >/dev/null 2>&1 \
   && [ "$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)" != "$(command -v zsh)" ]; then
  sudo -n chsh -s "$(command -v zsh)" "$USER" 2>/dev/null || true
fi

# Hand interactive bash off to zsh (covers the case chsh can't persist).
if [ -n "$BASH_VERSION" ] && [ -t 1 ] && command -v zsh >/dev/null 2>&1; then
  export SHELL="$(command -v zsh)"
  exec zsh
fi
