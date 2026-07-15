#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE=false
CHECK_ONLY=false
NIX_INSTALLER_VERSION="v3.21.0"
REMOVED_TARGETS=()
REMOVED_LINKS=()
SSH_CONFIG_MOVED=false

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

require_linux_systemd() {
  [[ "$(uname -s)" == "Linux" ]] || return

  if [[ "$(ps -p 1 -o comm=)" != "systemd" ]]; then
    echo "Linux installation requires systemd as PID 1 (including under WSL2)." >&2
    echo "Enable systemd, restart the environment, and rerun this installer." >&2
    exit 1
  fi
}

installer_metadata() {
  case "$(uname -s):$(uname -m)" in
  Linux:x86_64)
    printf '%s %s\n' \
      "nix-installer-x86_64-linux" \
      "b9911496659f0c35c642353d592926c024c205b597e8094bf73a42908a75e462"
    ;;
  Linux:aarch64 | Linux:arm64)
    printf '%s %s\n' \
      "nix-installer-aarch64-linux" \
      "d2ede080a0a7b34119362f4a8a6fb5e49a4d16b302ce54c96cd05514bdea6c7c"
    ;;
  Darwin:arm64 | Darwin:aarch64)
    printf '%s %s\n' \
      "nix-installer-aarch64-darwin" \
      "e506c3576e825be73e7b7a18ea34b22e0b1cffcbaa031b2ef0b4b93314aafeea"
    ;;
  *)
    echo "No pinned Nix installer is available for this platform." >&2
    return 1
    ;;
  esac
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  else
    shasum -a 256 "$1" | awk '{ print $1 }'
  fi
}

load_nix() {
  if command -v nix >/dev/null 2>&1; then
    return
  fi

  local artifact expected_sha actual_sha installer url
  read -r artifact expected_sha < <(installer_metadata)
  installer="$(mktemp)"
  trap 'rm -f -- "${installer:-}"' EXIT
  url="https://github.com/DeterminateSystems/nix-installer/releases/download/${NIX_INSTALLER_VERSION}/${artifact}"

  echo "Downloading Determinate Nix Installer ${NIX_INSTALLER_VERSION}..."
  curl --proto '=https' --tlsv1.2 -sSf -L \
    "$url" -o "$installer"

  actual_sha="$(sha256_file "$installer")"
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    echo "Nix installer checksum mismatch." >&2
    exit 1
  fi

  chmod u+x "$installer"
  "$installer" install --no-confirm

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

  rm -f -- "$installer"
  trap - EXIT
}

resolve_link() {
  local target="$1" link parent base canonical_parent
  link="$(readlink "$target")" || return 1
  if [[ "$link" != /* ]]; then
    link="$(dirname "$target")/$link"
  fi

  parent="$(dirname "$link")"
  base="$(basename "$link")"
  canonical_parent="$(cd -P "$parent" 2>/dev/null && pwd)" || return 1
  printf '%s/%s\n' "$canonical_parent" "$base"
}

migrate_legacy_stow_links() {
  local target resolved link
  local targets=(
    "$HOME/.zshrc"
    "$HOME/.tmux.conf"
    "$HOME/.config/nvim"
    "$HOME/.config/lazygit"
    "$HOME/.config/ghostty"
    "$HOME/.config/opencode"
    "$HOME/.claude/CLAUDE.md"
    "$HOME/.claude/agents"
  )

  for target in "${targets[@]}"; do
    [[ -L "$target" ]] || continue
    resolved="$(resolve_link "$target" 2>/dev/null || true)"
    if [[ "$target" == "$HOME/.config/opencode" ]] &&
      cmp -s "$target/opencode.json" "$DOTFILES_DIR/opencode/.config/opencode/opencode.json"; then
      resolved="$DOTFILES_DIR/opencode/.config/opencode"
    fi
    if [[ "$resolved" == "$DOTFILES_DIR"/* ]]; then
      link="$(readlink "$target")"
      REMOVED_TARGETS+=("$target")
      REMOVED_LINKS+=("$link")
      rm "$target" || return 1
    fi
  done
}

restore_legacy_stow_links() {
  local i target
  for ((i = 0; i < ${#REMOVED_TARGETS[@]}; i++)); do
    target="${REMOVED_TARGETS[$i]}"
    [[ -e "$target" || -L "$target" ]] || ln -s "${REMOVED_LINKS[$i]}" "$target"
  done
}

migrate_ssh_config() {
  local config="$HOME/.ssh/config"
  local local_config="$HOME/.ssh/config.local"
  local link

  [[ -e "$config" || -L "$config" ]] || return
  if [[ -L "$config" ]]; then
    link="$(readlink "$config")"
    [[ "$link" == /nix/store/* ]] && return
  fi

  if [[ -e "$local_config" || -L "$local_config" ]]; then
    echo "Cannot manage SSH config: both ~/.ssh/config and ~/.ssh/config.local exist." >&2
    return 1
  fi

  mv "$config" "$local_config" || return 1
  SSH_CONFIG_MOVED=true
}

restore_ssh_config() {
  $SSH_CONFIG_MOVED || return
  if [[ ! -e "$HOME/.ssh/config" && ! -L "$HOME/.ssh/config" ]]; then
    mv "$HOME/.ssh/config.local" "$HOME/.ssh/config"
  fi
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
  local profile flake_ref activation_ref

  require_bootstrap_tools
  profile="$(detect_profile)"
  require_linux_systemd
  load_nix

  flake_ref="path:$DOTFILES_DIR"
  activation_ref="${flake_ref}#homeConfigurations.${profile}.activationPackage"

  export DOTFILES_USER="${USER:?USER is not set}"
  export DOTFILES_HOME="$HOME"
  export DOTFILES_DIR

  if $UPDATE; then
    echo "Updating pinned flake inputs..."
    nix flake update "$flake_ref"
  fi

  if $CHECK_ONLY; then
    nix build --impure --no-link "$activation_ref"
    echo "Configuration builds successfully for ${profile}."
    exit 0
  fi

  echo "Building Home Manager profile ${profile}..."
  nix build --impure --no-link "$activation_ref"

  if ! migrate_legacy_stow_links; then
    restore_legacy_stow_links
    exit 1
  fi
  if ! migrate_ssh_config; then
    restore_legacy_stow_links
    exit 1
  fi

  echo "Activating Home Manager profile ${profile}..."
  if ! nix run --impure "${flake_ref}#home-manager" -- \
    switch -b backup --impure --flake "${flake_ref}#${profile}"; then
    # A non-zero exit after a generation is applied is non-fatal (for example,
    # reloading systemd user units on an already-degraded session). Only roll
    # back when Home Manager never activated; otherwise restoring the legacy
    # Stow links would clobber the freshly linked configuration.
    if [[ ! -e "$HOME/.local/state/nix/profiles/home-manager" ]]; then
      restore_ssh_config
      restore_legacy_stow_links
      exit 1
    fi
    echo "Home Manager applied a generation but reported a non-fatal activation error; continuing." >&2
  fi

  set_login_shell

  cat <<EOF

Environment activated successfully.

  Rebuild:  $DOTFILES_DIR/install.sh
  Update:   $DOTFILES_DIR/install.sh --update
  Rollback: home-manager generations

Restart your shell with: exec zsh
Authenticate once with: claude, cursor-agent, opencode
EOF
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
