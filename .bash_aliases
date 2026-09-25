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
        pre-commit install || true
      fi
    done

  cd - >/dev/null || return 1
  echo "Prep done."
}

install_orca() (
  set -e
  echo "Installing Orca dependencies..."
  sudo -n apt-get update
  sudo -n apt-get install -y \
    curl file jq xvfb zlib1g-dev ca-certificates git \
    libgtk-3-0t64 libnss3 libatk1.0-0t64 libatk-bridge2.0-0t64 libgbm1 libasound2t64 \
    libxtst6 libcups2t64 libdrm2 libxkbcommon0 libpango-1.0-0 libcairo2 libatspi2.0-0t64 \
    libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libxrender1 libx11-xcb1 \
    libxcb-dri3-0 libxss1

  echo "Downloading and installing Orca..."
  sudo -n mkdir -p /opt/orca
  sudo -n curl -fL https://github.com/stablyai/orca/releases/latest/download/orca-linux.AppImage \
    -o /opt/orca/orca-linux.AppImage
  sudo -n chmod +x /opt/orca/orca-linux.AppImage
  echo "Extracting Orca AppImage..."
  cd /opt/orca
  sudo -n ./orca-linux.AppImage --appimage-extract
  sudo -n chmod -R a+rX /opt/orca/squashfs-root
)

_orca_pids() {
  pgrep -u "$(id -u)" -f '^/opt/orca/squashfs-root/(orca-ide|AppRun)( --no-sandbox)? (serve|--serve)( |$)'
}

_orca_prepare_state() {
  local source_dir="$HOME/.config/orca"
  local state_dir="${ORCA_STATE_DIR:-/persistent/orca-data}"
  local staging_dir backup_dir

  if [[ "$state_dir" != /* ]] || ! mountpoint -q /persistent; then
    echo "Orca: use an absolute ORCA_STATE_DIR and mount /persistent first." >&2
    return 1
  fi
  mkdir -p "$HOME/.config" || return 1
  if [[ -L "$source_dir" ]]; then
    if [[ -d "$state_dir" && "$source_dir" -ef "$state_dir" ]]; then
      return 0
    fi
    echo "Orca: $source_dir is a broken or unexpected symlink; leaving it unchanged." >&2
    return 1
  fi
  if [[ -e "$source_dir" ]]; then
    if [[ -d "$source_dir" && -d "$state_dir" && ! -L "$state_dir" ]]; then
      local source_path state_path
      source_path=$(realpath -e -- "$source_dir") || return 1
      state_path=$(realpath -e -- "$state_dir") || return 1
      if [[ "$state_path" == "$source_path" || "$state_path" == "$source_path/"* ]]; then
        echo "Orca: persistent state must be outside the local configuration directory." >&2
        return 1
      fi
      rm -rf -- "$source_dir" || return 1
      ln -sT "$state_dir" "$source_dir"
      return $?
    fi
    if [[ ! -d "$source_dir" || -e "$state_dir" || -L "$state_dir" ]]; then
      echo "Orca: conflicting local/persistent state; choose the authoritative directory before starting." >&2
      return 1
    fi
    mkdir -p "$(dirname "$state_dir")" || return 1
    staging_dir=$(mktemp -d "${state_dir}.migration.XXXXXX") || return 1
    if ! cp -a "$source_dir/." "$staging_dir/"; then
      echo "Orca: copy failed; original untouched, partial copy at $staging_dir." >&2
      return 1
    fi
    chmod 700 "$staging_dir" || return 1
    mv -T -n "$staging_dir" "$state_dir" || return 1
    [[ ! -d "$staging_dir" ]] || return 1
    backup_dir=$(mktemp -d "$HOME/.config/orca.backup.XXXXXX") || return 1
    mv -T "$source_dir" "$backup_dir/orca" || return 1
    echo "Orca: original configuration retained at $backup_dir/orca"
  else
    [[ ! -L "$state_dir" ]] || return 1
    mkdir -p "$state_dir" || return 1
    chmod 700 "$state_dir" || return 1
  fi
  ln -sT "$state_dir" "$source_dir"
}

_orca_stop() {
  local server_pid server_pids
  server_pids=$(_orca_pids) || server_pids=
  [[ -n "$server_pids" ]] || return 0
  while IFS= read -r server_pid; do
    kill -TERM "$server_pid" 2>/dev/null || {
      ! kill -0 "$server_pid" 2>/dev/null || return 1
    }
  done <<< "$server_pids"
  while IFS= read -r server_pid; do
    if ! timeout 30 tail --pid="$server_pid" -f /dev/null; then
      echo "Orca: shutdown timed out; no state was moved. Check PID $server_pid." >&2
      return 1
    fi
  done <<< "$server_pids"
}

_orca_control() (
  umask 077
  local action="$1" tailscale_ip launch_pid
  local lock_dir="${XDG_RUNTIME_DIR:-$HOME/.cache}/orca-control"
  mkdir -p "$lock_dir" || return 1
  exec 9>"$lock_dir/lifecycle.lock" || return 1
  if ! flock -n 9; then
    echo "Orca: another lifecycle command is in progress." >&2
    return 1
  fi
  case "$action" in
    stop) _orca_stop; return $? ;;
    restart) _orca_stop || return 1 ;;
    start) ;;
    *) return 1 ;;
  esac
  if _orca_pids >/dev/null; then
    echo "Orca is already running. Use restart_orca to migrate its configuration."
    return 0
  fi
  if [[ ! -x /opt/orca/squashfs-root/AppRun ]]; then
    echo "Orca is not installed. Run install_orca, then start_orca." >&2
    return 1
  fi
  tailscale_ip=$(tailscale ip -4) || return 1
  [[ -n "$tailscale_ip" ]] || return 1
  _orca_prepare_state || return 1
  nohup /opt/orca/squashfs-root/AppRun serve --pairing-address "$tailscale_ip" \
    </dev/null >>"$HOME/orca.log" 2>&1 9>&- &
  launch_pid=$!
  local deadline=$((SECONDS + 10))
  until _orca_pids >/dev/null; do
    if ! kill -0 "$launch_pid" 2>/dev/null || (( SECONDS >= deadline )); then
      echo "Orca: launch was not confirmed; check $HOME/orca.log before retrying." >&2
      return 1
    fi
    sleep 0.1
  done
  echo "Orca launched. Log: $HOME/orca.log"
)

start_orca() {
  _orca_control start
}

stop_orca() {
  _orca_control stop
}

restart_orca() {
  _orca_control restart
}

status_orca() {
  if _orca_pids >/dev/null; then
    echo "Orca is running."
  else
    echo "Orca is not running."
  fi
}

save_orca_config() {
  restart_orca
}

if [[ "${ORCA_AUTOSTART:-1}" == 1 ]]; then
  start_orca
fi

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
