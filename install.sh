#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
#  Dotfiles installer
# ─────────────────────────────────────────────

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

ok() { echo -e "${GREEN}  ✓${RESET} $*"; }
info() { echo -e "${CYAN}  →${RESET} $*"; }
warn() { echo -e "${YELLOW}  !${RESET} $*"; }
fail() {
  echo -e "${RED}  ✗${RESET} $*"
  exit 1
}
section() { echo -e "\n${BOLD}$*${RESET}"; }

# ─────────────────────────────────────────────
#  OS detection
# ─────────────────────────────────────────────
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  elif [[ -f /etc/debian_version ]]; then
    OS="debian"
  elif [[ -f /etc/arch-release ]]; then
    OS="arch"
  else
    fail "Unsupported OS. Add support for your platform and send a PR."
  fi
}

# ─────────────────────────────────────────────
#  Package installation helpers
# ─────────────────────────────────────────────
install_pkg() {
  local pkg="$1"
  local cmd="${2:-$1}" # command to check; defaults to package name

  if command -v "$cmd" &>/dev/null; then
    ok "$cmd already installed"
    return
  fi

  info "Installing $pkg..."
  case "$OS" in
  macos) brew install "$pkg" ;;
  debian) sudo apt-get install -y "$pkg" ;;
  arch) sudo pacman -S --noconfirm "$pkg" ;;
  esac
  ok "$pkg installed"
}

# ─────────────────────────────────────────────
#  Preferences
# ─────────────────────────────────────────────
ask_preferences() {
  section "Installation Options"
  read -p "Install core terminal environment (Zsh, Tmux, Neovim)? [Y/n] " OPT_CORE
  OPT_CORE=${OPT_CORE:-Y}
  read -p "Install Claude Code? [y/N] " OPT_CLAUDE
  OPT_CLAUDE=${OPT_CLAUDE:-N}
  read -p "Install Gemini CLI? [y/N] " OPT_GEMINI
  OPT_GEMINI=${OPT_GEMINI:-N}
  read -p "Install OpenCode? [y/N] " OPT_OPENCODE
  OPT_OPENCODE=${OPT_OPENCODE:-N}
}

# ─────────────────────────────────────────────
#  1. System packages
# ─────────────────────────────────────────────
install_system_packages() {
  section "System packages"

  case "$OS" in
  macos)
    if ! command -v brew &>/dev/null; then
      info "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
      ok "Homebrew already installed"
    fi
    ;;
  debian)
    sudo apt-get update -qq
    ;;
  esac

  install_pkg stow
  install_pkg git
  install_pkg zsh
  install_pkg tmux
  install_pkg neovim nvim
  install_pkg lazygit
  install_pkg curl
  install_pkg unzip
  install_pkg fontconfig fc-cache

  # Telescope search backends
  case "$OS" in
  macos)
    install_pkg ripgrep rg
    install_pkg fd
    ;;
  debian)
    install_pkg ripgrep rg
    # fd is packaged as fd-find on Debian
    if ! command -v fd &>/dev/null && ! command -v fdfind &>/dev/null; then
      info "Installing fd-find..."
      sudo apt-get install -y fd-find
    elif command -v fd &>/dev/null; then
      ok "fd already installed"
    fi

    # Symlink fdfind → fd if needed
    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
      mkdir -p "$HOME/.local/bin"
      ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
      ok "fd symlinked from fdfind"
    fi
    ;;
  arch)
    install_pkg ripgrep rg
    install_pkg fd
    ;;
  esac

  # Python — required by Neovim venv and Mason Python-based LSP servers
  case "$OS" in
  macos)
    install_pkg python3
    ;;
  debian)
    install_pkg python3
    if ! dpkg -s python3-venv &>/dev/null 2>&1; then
      info "Installing python3-venv..."
      sudo apt-get install -y python3-venv python3-pip
      ok "python3-venv installed"
    else
      ok "python3-venv already installed"
    fi
    ;;
  arch)
    install_pkg python3 python
    ;;
  esac

  # Node — required by many LSP servers and Claude Code
  if ! command -v node &>/dev/null; then
    info "Installing Node.js..."
    case "$OS" in
    macos) brew install node ;;
    debian)
      curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
      sudo apt-get install -y nodejs
      ;;
    arch) sudo pacman -S --noconfirm nodejs npm ;;
    esac
    ok "Node.js installed"
  else
    ok "Node.js already installed ($(node --version))"
  fi

  # Go — required by gopls and Go tooling
  if command -v go &>/dev/null; then
    ok "Go already installed ($(go version | awk '{print $3}'))"
  else
    info "Installing Go..."
    local go_version="1.26.1"
    local go_arch="amd64"
    [[ "$(uname -m)" == "aarch64" || "$(uname -m)" == "arm64" ]] && go_arch="arm64"
    local go_os="linux"
    [[ "$OS" == "macos" ]] && go_os="darwin"
    local go_tarball="go${go_version}.${go_os}-${go_arch}.tar.gz"

    curl -fsSL "https://go.dev/dl/${go_tarball}" -o "/tmp/${go_tarball}"
    mkdir -p "$HOME/.local"
    rm -rf "$HOME/.local/go"
    tar -C "$HOME/.local" -xzf "/tmp/${go_tarball}"
    rm "/tmp/${go_tarball}"
    ok "Go ${go_version} installed to ~/.local/go"
  fi
}

# ─────────────────────────────────────────────
#  2. Zsh: Oh My Zsh + plugins + theme
# ─────────────────────────────────────────────
install_zsh() {
  section "Zsh"

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Installing Oh My Zsh..."
    # Non-interactive install — don't change the default shell or open a new one
    RUNZSH=no CHSH=no sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "Oh My Zsh installed"
  else
    ok "Oh My Zsh already installed"
  fi

  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  if [[ ! -d "$custom/themes/powerlevel10k" ]]; then
    info "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
      "$custom/themes/powerlevel10k"
    ok "Powerlevel10k installed"
  else
    ok "Powerlevel10k already installed"
  fi

  if [[ ! -d "$custom/plugins/zsh-syntax-highlighting" ]]; then
    info "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
      "$custom/plugins/zsh-syntax-highlighting"
    ok "zsh-syntax-highlighting installed"
  else
    ok "zsh-syntax-highlighting already installed"
  fi

  if [[ ! -d "$custom/plugins/zsh-autosuggestions" ]]; then
    info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions.git \
      "$custom/plugins/zsh-autosuggestions"
    ok "zsh-autosuggestions installed"
  else
    ok "zsh-autosuggestions already installed"
  fi

  # Change default shell to zsh if not already
  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ "$SHELL" != "$zsh_path" ]]; then
    info "Changing default shell to zsh..."
    if [[ "$OS" == "macos" ]]; then
      if ! grep -Fxq "$zsh_path" /etc/shells; then
        info "Adding $zsh_path to /etc/shells (requires sudo)"
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
      fi
    fi
    chsh -s "$zsh_path"
    ok "Default shell changed to zsh"
  else
    ok "zsh is already the default shell"
  fi
}

# ─────────────────────────────────────────────
#  3. tmux: TPM
# ─────────────────────────────────────────────
install_tmux() {
  section "tmux"

  if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    info "Installing TPM (Tmux Plugin Manager)..."
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    ok "TPM installed"
  else
    ok "TPM already installed"
  fi
}

# ─────────────────────────────────────────────
#  4. Neovim: python venv for pynvim
# ─────────────────────────────────────────────
install_neovim_extras() {
  section "Neovim"

  if [[ ! -d "$HOME/.nvim-venv" ]]; then
    if command -v python3 &>/dev/null; then
      info "Creating Neovim python venv at ~/.nvim-venv..."
      python3 -m venv "$HOME/.nvim-venv"
      "$HOME/.nvim-venv/bin/pip" install --quiet pynvim
      ok "Neovim python venv created"
    else
      warn "python3 not found — skipping Neovim venv (some plugins may not work)"
    fi
  else
    ok "Neovim python venv already exists"
  fi
}

# ─────────────────────────────────────────────
#  5. Fonts
# ─────────────────────────────────────────────
install_fonts() {
  section "Fonts"

  if fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    ok "JetBrainsMono Nerd Font already installed"
    return
  fi

  case "$OS" in
  macos)
    brew install --cask font-jetbrains-mono-nerd-font
    ;;
  arch)
    sudo pacman -S --noconfirm ttf-jetbrains-mono-nerd
    ;;
  debian)
    info "Installing JetBrainsMono Nerd Font..."
    local font_dir="$HOME/.local/share/fonts/JetBrainsMono"
    mkdir -p "$font_dir"
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" \
      -o /tmp/JetBrainsMono.zip
    unzip -o -q /tmp/JetBrainsMono.zip -d "$font_dir"
    rm /tmp/JetBrainsMono.zip
    fc-cache -f "$font_dir"
    ;;
  esac

  ok "JetBrainsMono Nerd Font installed"
}

# ─────────────────────────────────────────────
#  6. Catppuccin zsh-syntax-highlighting
# ─────────────────────────────────────────────
install_zsh_catppuccin() {
  section "Catppuccin zsh-syntax-highlighting"

  local theme_file="$HOME/.zsh/catppuccin_macchiato-zsh-syntax-highlighting.zsh"
  if [[ -f "$theme_file" ]]; then
    ok "Catppuccin zsh theme already installed"
    return
  fi

  info "Installing Catppuccin macchiato zsh-syntax-highlighting..."
  mkdir -p "$HOME/.zsh"
  curl -fsSL \
    "https://raw.githubusercontent.com/catppuccin/zsh-syntax-highlighting/main/themes/catppuccin_macchiato-zsh-syntax-highlighting.zsh" \
    -o "$theme_file"
  ok "Catppuccin zsh theme installed"
}

# ─────────────────────────────────────────────
#  7. Claude Code
# ─────────────────────────────────────────────
install_claude() {
  section "Claude Code"

  if command -v claude &>/dev/null; then
    ok "Claude Code already installed ($(claude --version 2>/dev/null || echo 'unknown version'))"
  else
    info "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
    ok "Claude Code installed"
  fi
}

# ─────────────────────────────────────────────
#  8. Gemini CLI
# ─────────────────────────────────────────────
install_gemini() {
  section "Gemini CLI"

  if command -v gemini &>/dev/null; then
    ok "Gemini CLI already installed ($(gemini --version 2>/dev/null || echo 'unknown version'))"
  else
    info "Installing Gemini CLI..."
    if command -v npm &>/dev/null; then
      npm install -g @google/gemini-cli
      ok "Gemini CLI installed"
    else
      warn "npm not found — cannot install Gemini CLI"
    fi
  fi
}

# ─────────────────────────────────────────────
#  9. OpenCode
# ─────────────────────────────────────────────
install_opencode() {
  section "OpenCode"

  if command -v opencode &>/dev/null; then
    ok "OpenCode already installed ($(opencode --version 2>/dev/null || echo 'unknown version'))"
  else
    info "Installing OpenCode..."
    install_pkg opencode
    ok "OpenCode installed"
  fi
}

# ─────────────────────────────────────────────
#  10. Stow all packages
# ─────────────────────────────────────────────
stow_packages() {
  section "Stowing dotfiles"

  cd "$DOTFILES_DIR"

    local packages=()
  if [[ "$OPT_CORE" =~ ^[Yy]$ ]]; then
    packages+=(nvim tmux zshrc lazygit ghostty)
  fi
  if [[ "$OPT_CLAUDE" =~ ^[Yy]$ ]]; then packages+=(claude); fi
  if [[ "$OPT_GEMINI" =~ ^[Yy]$ ]]; then packages+=(gemini); fi
  if [[ "$OPT_OPENCODE" =~ ^[Yy]$ ]]; then packages+=(opencode); fi

  if [[ ${#packages[@]} -eq 0 ]]; then
    info "No packages selected to stow."
    return
  fi

  for pkg in "${packages[@]}"; do
    if [[ ! -d "$pkg" ]]; then
      warn "Package '$pkg' not found in $DOTFILES_DIR — skipping"
      continue
    fi

    if [[ "$pkg" == "zshrc" && -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
      local backup="$HOME/.zshrc.pre-stow"
      if [[ -f "$backup" ]]; then
        backup="$HOME/.zshrc.pre-stow.$(date +%s)"
      fi
      info "Backing up existing ~/.zshrc to $backup"
      mv "$HOME/.zshrc" "$backup"
    fi

    local stow_output
    if stow_output=$(stow --restow "$pkg" 2>&1 | grep -v "BUG in find_stowed_path"); then
      ok "stow $pkg"
    else
      warn "stow $pkg failed:"
      echo "$stow_output" >&2
    fi
  done
}

# ─────────────────────────────────────────────
#  Summary
# ─────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}────────────────────────────────────────${RESET}"
  echo -e "${BOLD}  Done. Manual steps remaining:${RESET}"
  echo -e "${BOLD}────────────────────────────────────────${RESET}"
  echo ""
  if [[ "$OPT_CORE" =~ ^[Yy]$ ]]; then
    echo -e "  ${CYAN}Zsh${RESET}"
    echo "    Restart your shell, then run: p10k configure"
    echo ""
    echo -e "  ${CYAN}tmux${RESET}"
    echo "    Start tmux, then press: Ctrl-a + I  (install plugins)"
    echo ""
    echo -e "  ${CYAN}Neovim${RESET}"
    echo "    Open nvim — lazy.nvim will auto-install plugins on first launch"
    echo "    Then run: :MasonInstall <lsp-server> for any LSP servers you need"
    echo ""
  fi

  if [[ "$OPT_CLAUDE" =~ ^[Yy]$ ]]; then
    echo -e "  ${CYAN}Claude Code${RESET}"
    echo "    Run: claude  (follow auth prompts on first launch)"
    echo ""
  fi

  if [[ "$OPT_GEMINI" =~ ^[Yy]$ ]]; then
    echo -e "  ${CYAN}Gemini CLI${RESET}"
    echo "    Run: gemini  (follow auth prompts on first launch)"
    echo ""
  fi

  if [[ "$OPT_OPENCODE" =~ ^[Yy]$ ]]; then
    echo -e "  ${CYAN}OpenCode${RESET}"
    echo "    Run: opencode  (follow auth prompts on first launch)"
    echo ""
  fi
}

# ─────────────────────────────────────────────
#  Entry point
# ─────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}  Dotfiles installer${RESET}"
  echo -e "  ${DOTFILES_DIR}"
  echo ""

  detect_os
  info "Detected OS: $OS"

  ask_preferences

  if [[ "$OPT_CORE" =~ ^[Yy]$ ]]; then
    install_system_packages
    install_fonts
    install_zsh
    install_zsh_catppuccin
    install_tmux
    install_neovim_extras
  fi

  if [[ "$OPT_CLAUDE" =~ ^[Yy]$ ]]; then install_claude; fi
  if [[ "$OPT_GEMINI" =~ ^[Yy]$ ]]; then install_gemini; fi
  if [[ "$OPT_OPENCODE" =~ ^[Yy]$ ]]; then install_opencode; fi

  stow_packages
  print_summary
}

main "$@"
