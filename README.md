# Dotfiles

A pinned, repeatable development environment built with Nix flakes and Home
Manager. The same configuration supports:

- x86_64 Linux, including Ubuntu on WSL2
- aarch64 Linux
- Apple Silicon macOS

Intel macOS is excluded because current nixpkgs no longer supports it. The
installer fails clearly rather than selecting an unmaintained package set.

## Install

Clone the repository anywhere under the target account, then run:

```sh
git clone <repository-url> ~/dotfiles
cd ~/dotfiles
./install.sh
```

The installer:

1. Detects the current OS and architecture.
2. Installs Determinate Nix when Nix is not already available.
3. Migrates links previously created by Stow.
4. Builds the exact versions pinned in `flake.lock`.
5. Activates the matching Home Manager profile.

The username, home directory, and repository path are detected at runtime; no
account-specific path is embedded in the configuration.

Restart the shell after the first activation:

```sh
exec zsh
```

## Maintain

Reapply the current lock file:

```sh
./install.sh
```

Evaluate without changing the active environment:

```sh
./install.sh --check
```

Update all pinned inputs, including Neovim nightly and AI CLIs:

```sh
./install.sh --update
```

Home Manager keeps previous generations. List or roll them back with:

```sh
home-manager generations
home-manager switch --rollback
```

## Managed tools

Home Manager installs and configures:

- Zsh, Oh My Zsh, Powerlevel10k, and shell plugins
- tmux with Catppuccin and sensible
- pinned Neovim nightly
- Git, delta, lazygit, ripgrep, fd, fzf, jq, and terminal utilities
- Go, Rust, Node.js, Python, C tooling, language servers, formatters, linters,
  test dependencies, and debuggers used by the Neovim configuration
- Claude Code and Cursor Agent
- JetBrains Mono Nerd Font

Authenticate each AI CLI once after installation:

```sh
claude
cursor-agent
```

## tmux development sessions

`mux [session] [directory]` creates one tmux window with exactly two panes:

- pane 1: Neovim
- pane 2: Cursor Agent, falling back to Claude Code

Running `mux` again reuses the existing session. From inside tmux it switches
clients instead of attempting a nested attachment.

## Layout

- `flake.nix` and `flake.lock`: pinned inputs and platform profiles
- `home/default.nix`: packages and Home Manager configuration
- `zshrc/init.zsh`: aliases, local configuration, and `mux`
- `tmux/tmux.conf`: tmux key bindings and status configuration
- `nvim/.config/nvim`: Neovim configuration
- `install.sh`: minimal Nix bootstrap and activation entry point

Application configuration directories remain linked to this repository, so
editing them takes effect immediately. Package versions and generated shell or
tmux configuration remain declarative and rollback-capable.
