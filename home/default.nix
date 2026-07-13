{
  config,
  pkgs,
  lib,
  system,
  dotfilesDir,
  neovimPackage,
  ...
}:
let
  isDarwin = pkgs.stdenv.isDarwin;
  python = pkgs.python3.withPackages (
    pythonPackages: with pythonPackages; [
      debugpy
      pynvim
      pytest
    ]
  );
  outOfStore = path: config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/${path}";
in
{
  home.stateVersion = "26.05";

  home.packages =
    with pkgs;
    [
      neovimPackage

      # Core terminal environment
      bat
      curl
      delta
      eza
      fd
      fzf
      git
      gnumake
      jq
      keychain
      lazygit
      ripgrep
      tree-sitter
      unzip
      wget

      # Language runtimes and compilers
      cargo
      go
      nodejs_24
      python
      rust-analyzer
      rustc

      # Language servers
      bash-language-server
      clang-tools
      dockerfile-language-server
      gopls
      lua-language-server
      marksman
      pyright
      sqls
      terraform-ls
      typescript-language-server
      vscode-langservers-extracted
      yaml-language-server

      # Formatters, linters, and debuggers
      delve
      eslint
      golangci-lint
      gotools
      hadolint
      markdownlint-cli
      prettier
      prettierd
      ruff
      shellcheck
      shfmt
      stylua
      vale

      # AI command-line tools
      claude-code
      cursor-cli

      # Fonts
      nerd-fonts.jetbrains-mono
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      gcc
      xclip
    ];

  home.sessionPath = [
    "$HOME/.nix-profile/bin"
    "$HOME/go/bin"
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    NVIM_NOTTYFAST = "1";
  };

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      share = true;
    };
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "keychain"
      ];
      theme = "";
      extraConfig = ''
        zstyle :omz:plugins:keychain agents ssh
        zstyle :omz:plugins:keychain identities id_ed25519
        zstyle :omz:plugins:keychain options --quiet
      '';
    };
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];
    initContent = builtins.readFile ../zshrc/init.zsh;
  };

  programs.tmux = {
    enable = true;
    baseIndex = 1;
    clock24 = true;
    escapeTime = 0;
    keyMode = "vi";
    mouse = true;
    prefix = "C-a";
    sensibleOnTop = false;
    terminal = "tmux-256color";
    plugins = with pkgs.tmuxPlugins; [
      sensible
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor 'macchiato'
          set -g @catppuccin_window_status_style 'rounded'
        '';
      }
    ];
    extraConfig = builtins.readFile ../tmux/tmux.conf;
  };

  fonts.fontconfig.enable = !isDarwin;

  home.file = {
    ".config/nvim".source = outOfStore "nvim/.config/nvim";
    ".config/lazygit".source = outOfStore "lazygit/.config/lazygit";
    ".config/ghostty".source = outOfStore "ghostty/.config/ghostty";
    ".claude/CLAUDE.md".source = outOfStore "claude/.claude/CLAUDE.md";
    ".claude/agents".source = outOfStore "claude/.claude/agents";
  };

  home.activation.verifyDotfilesDirectory = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [[ ! -d ${lib.escapeShellArg dotfilesDir} ]]; then
      echo "Dotfiles directory does not exist: ${dotfilesDir}" >&2
      exit 1
    fi
  '';
}
