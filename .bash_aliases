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

# Append ll git aliase if it doesn't exist in .zshrc
if [[ -f "$HOME/.zshrc" ]] && ! grep -q "alias ll='ls -la'" "$HOME/.zshrc"; then
  echo "alias ll='ls -la'" >> "$HOME/.zshrc"
fi

git config --global user.email "$EMAIL_GIT"
git config --global user.name "$USERNAME_GIT" 


# In superbank, use the gh login token, not the Coder app token, which has no access to solana-rpc.
# gh() { case "$PWD" in /workspaces/git/superbank*) GH_TOKEN_NO_CODER=1 command gh "$@";; *) command gh "$@";; esac; }

# In superbank, git uses the gh login token, not the Coder app token, which has no access to solana-rpc.
sb=/workspaces/git/superbank
if [ -d "$sb/.git" ] && ! git -C "$sb" config --local --get-all credential.https://github.com.helper | grep -q 'gh auth git-credential'; then
  git -C "$sb" config --local --add credential.https://github.com.helper ''
  git -C "$sb" config --local --add credential.https://github.com.helper '!env -u GH_TOKEN -u GITHUB_TOKEN GH_TOKEN_NO_CODER=1 gh auth git-credential'
fi
unset sb

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
  mkdir -p /workspaces/git && ln -s /workspaces/git ~/git
  cd ~/git || return 1

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
        pre-commit install || true
      fi
    done

  cd - >/dev/null || return 1
  echo "Prep done."
}

test -d ~/git/rpcpool || prep_env

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

# Interactive bash hands over to zsh, because Orca starts terminals with the boot-time SHELL=/bin/bash.
if [[ $- == *i* && -z ${ZSH_VERSION:-} && -z ${NO_ZSH:-} && -x /usr/bin/zsh ]]; then export SHELL=/usr/bin/zsh; exec /usr/bin/zsh -l; fi
