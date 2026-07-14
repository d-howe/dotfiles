# Dotfiles

A pinned, repeatable development environment built with Nix flakes and Home
Manager. The same configuration supports:

- x86_64 Linux, including Ubuntu on WSL2
- aarch64 Linux
- Apple Silicon macOS

Intel macOS is excluded because current nixpkgs no longer supports it. The
installer fails clearly rather than selecting an unmaintained package set.
Linux installations require systemd; Ubuntu on WSL2 must have systemd enabled.

## Install

Clone the repository anywhere under the target account, then run:

```sh
git clone https://github.com/d-howe/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The installer:

1. Detects the current OS and architecture.
2. Downloads a pinned Determinate Nix installer and verifies its SHA-256 hash
   when Nix is not already available.
3. Builds the matching Home Manager profile before changing existing links.
4. Migrates links previously created by Stow.
5. Activates the exact versions pinned in `flake.lock`.

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

Build the activation package without changing the active environment:

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
- Claude Code, Cursor Agent, and OpenCode
- JetBrains Mono Nerd Font

Authenticate each AI CLI once after installation:

```sh
claude
cursor-agent
opencode
```

On Linux, Home Manager starts a user-scoped SSH agent. The first SSH operation
after login asks for the key passphrase, then OpenSSH caches the key for the
rest of that login session.

## tmux development sessions

`mux [session] [directory] [agent]` creates one tmux window with exactly two
panes:

- pane 1: Neovim
- pane 2: the selected AI agent

Supported agents are `cursor-agent`, `opencode`, and `claude`. Selection uses
the third argument first, then `MUX_AGENT`, then defaults to Cursor Agent. An
explicit unavailable agent returns an error; the implicit default falls back
through Cursor Agent, OpenCode, and Claude Code.

Set a machine-level default in the untracked `~/.zshrc.local`:

```sh
export MUX_AGENT=opencode
```

Override it for one new session:

```sh
mux project ~/dev/project claude
```

Running `mux` again reuses the existing session without changing its directory
or agent. From inside tmux it switches clients instead of attempting a nested
attachment.

## Layout

- `flake.nix` and `flake.lock`: pinned inputs and platform profiles
- `home/default.nix`: packages and Home Manager configuration
- `zshrc/init.zsh`: aliases, local configuration, and `mux`
- `tmux/tmux.conf`: tmux key bindings and status configuration
- `nvim/.config/nvim`: Neovim configuration
- `opencode/.config/opencode`: OpenCode configuration and specialist agents
- `install.sh`: minimal Nix bootstrap and activation entry point

Application configuration directories remain linked to this repository, so
editing them takes effect immediately. Package versions and generated shell or
tmux configuration remain declarative and rollback-capable.
