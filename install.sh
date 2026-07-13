#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE=false
CHECK_ONLY=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [--update] [--check]

  --update  Refresh flake.lock before applying the environment
  --check   Evaluate the configuration without activating it
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --update) UPDATE=true ;;
  --check) CHECK_ONLY=true ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown option: $1" >&2
    usage >&2
    exit 2
    ;;
  esac
  shift
done

require_bootstrap_tools() {
  local missing=()
  command -v curl >/dev/null 2>&1 || missing+=(curl)
  command -v git >/dev/null 2>&1 || missing+=(git)

  if [[ ${#missing[@]} -eq 0 ]]; then
    return
  fi

  if [[ "$(uname -s)" == "Linux" ]] && command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y "${missing[@]}"
  else
    echo "Install these bootstrap tools first: ${missing[*]}" >&2
    exit 1
  fi
}

detect_profile() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "${os}:${arch}" in
  Linux:x86_64) echo "linux-x86_64" ;;
  Linux:aarch64 | Linux:arm64) echo "linux-aarch64" ;;
  Darwin:arm64 | Darwin:aarch64) echo "darwin-aarch64" ;;
  Darwin:x86_64)
    echo "Intel macOS is not supported by current nixpkgs." >&2
    exit 1
    ;;
  *)
    echo "Unsupported platform: ${os} ${arch}" >&2
    exit 1
    ;;
  esac
}

load_nix() {
  if command -v nix >/dev/null 2>&1; then
    return
  fi

  echo "Installing Determinate Nix..."
  curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix |
    sh -s -- install --no-confirm

  if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck disable=SC1091
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  elif [[ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi

  command -v nix >/dev/null 2>&1 || {
    echo "Nix was installed but is not available in this shell. Start a new shell and rerun." >&2
    exit 1
  }
}

remove_legacy_stow_links() {
  local target resolved
  local targets=(
    "$HOME/.zshrc"
    "$HOME/.tmux.conf"
    "$HOME/.config/nvim"
    "$HOME/.config/lazygit"
    "$HOME/.config/ghostty"
    "$HOME/.claude/CLAUDE.md"
    "$HOME/.claude/agents"
  )

  for target in "${targets[@]}"; do
    [[ -L "$target" ]] || continue
    resolved="$(readlink -f "$target" 2>/dev/null || true)"
    if [[ "$resolved" == "$DOTFILES_DIR"/* ]]; then
      rm "$target"
    fi
  done
}

set_login_shell() {
  local zsh_path="$HOME/.nix-profile/bin/zsh"
  [[ -x "$zsh_path" ]] || return
  [[ "$(basename "${SHELL:-}")" == "zsh" ]] && return

  if grep -Fxq "$zsh_path" /etc/shells; then
    if chsh -s "$zsh_path"; then
      echo "Login shell changed to Nix-managed Zsh."
    else
      echo "Could not change the login shell automatically; continue with: exec zsh" >&2
    fi
  else
    echo "Zsh is installed. To make it the login shell, add $zsh_path to /etc/shells and run chsh." >&2
  fi
}

main() {
  require_bootstrap_tools
  load_nix

  local profile flake_ref
  profile="$(detect_profile)"
  flake_ref="path:$DOTFILES_DIR"

  export DOTFILES_USER="${USER:?USER is not set}"
  export DOTFILES_HOME="$HOME"
  export DOTFILES_DIR

  if $UPDATE; then
    echo "Updating pinned flake inputs..."
    nix flake update "$flake_ref"
  fi

  if $CHECK_ONLY; then
    nix eval --impure --raw \
      "${flake_ref}#homeConfigurations.${profile}.activationPackage.drvPath"
    echo
    echo "Configuration evaluates successfully for ${profile}."
    exit 0
  fi

  remove_legacy_stow_links

  echo "Activating Home Manager profile ${profile}..."
  nix run --impure "${flake_ref}#home-manager" -- \
    switch --impure --flake "${flake_ref}#${profile}"

  set_login_shell

  cat <<EOF

Environment activated successfully.

  Rebuild:  $DOTFILES_DIR/install.sh
  Update:   $DOTFILES_DIR/install.sh --update
  Rollback: home-manager generations

Restart your shell with: exec zsh
Authenticate once with: claude, cursor-agent
EOF
}

main
