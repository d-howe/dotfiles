{
  description = "Cross-platform development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      neovim-nightly,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      identity = {
        username = builtins.getEnv "DOTFILES_USER";
        homeDirectory = builtins.getEnv "DOTFILES_HOME";
        dotfilesDirectory = builtins.getEnv "DOTFILES_DIR";
      };

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

      mkHome =
        system:
        let
          pkgs = mkPkgs system;
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit inputs system;
            dotfilesDir = identity.dotfilesDirectory;
            neovimPackage = neovim-nightly.packages.${system}.default;
          };
          modules = [
            ./home/default.nix
            {
              assertions = [
                {
                  assertion =
                    identity.username != "" && identity.homeDirectory != "" && identity.dotfilesDirectory != "";
                  message = "Set DOTFILES_USER, DOTFILES_HOME, and DOTFILES_DIR before activation.";
                }
              ];
              home.username = identity.username;
              home.homeDirectory = identity.homeDirectory;
            }
          ];
        };
    in
    {
      homeConfigurations = {
        linux-x86_64 = mkHome "x86_64-linux";
        linux-aarch64 = mkHome "aarch64-linux";
        darwin-aarch64 = mkHome "aarch64-darwin";
      };

      packages = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          home-manager = home-manager.packages.${system}.home-manager;
          formatter = pkgs.nixfmt-tree;
          default = home-manager.packages.${system}.home-manager;
        }
      );

      formatter = forAllSystems (system: (mkPkgs system).nixfmt-tree);
    };
}
