{
  description = "mr04vv's dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    arto.url = "github:arto-app/Arto";
    gh-review-watcher = {
      url = "github:EdV4H/gh-review-watcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, nixos-wsl, neovim-nightly-overlay, arto, gh-review-watcher, ... }:
  let
    hosts = {
      mac-m1 = {
        system = "aarch64-darwin";
        username = "takutomori";
        homeDir = "/Users/takutomori";
      };
      mac-intel = {
        system = "x86_64-darwin";
        username = "mooriii";
        homeDir = "/Users/mooriii";
      };
      wsl = {
        system = "x86_64-linux";
        username = "mr04v";
        homeDir = "/home/mr04v";
      };
    };

    mkDarwin = name: hostConfig:
      let
        inherit (hostConfig) system username homeDir;
      in
      nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit self username homeDir; };
        modules = [
          # User configuration
          {
            users.users.${username} = {
              name = username;
              home = homeDir;
            };
          }

          # Home Manager integration
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.backupFileExtension = "backup";
            home-manager.useUserPackages = true;
            home-manager.users.${username} = {
              imports = [
                ./modules/home
                ./hosts/${name}.nix
              ];
              home.stateVersion = "23.11";
            };
            home-manager.extraSpecialArgs = { inherit neovim-nightly-overlay arto gh-review-watcher; };
          }

          # nix-darwin modules
          ./modules/darwin

          # Custom overlays
          {
            nixpkgs.overlays = [
              (import ./overlays/mo.nix)
              (import ./overlays/gh.nix)
            ];
          }

          # nixpkgs config
          {
            nixpkgs.config.allowUnfree = true;
          }

          # Determinate Nix compatibility
          {
            nix.enable = false;
          }
        ];
      };
    mkNixos = name: hostConfig:
      let
        inherit (hostConfig) system username homeDir;
      in
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit self username homeDir; };
        modules = [
          # WSL configuration
          nixos-wsl.nixosModules.wsl
          {
            wsl = {
              enable = true;
              defaultUser = username;
            };
            system.stateVersion = "23.11";
          }

          # User configuration
          {
            users.users.${username} = {
              isNormalUser = true;
              home = homeDir;
              extraGroups = [ "wheel" ];
            };
          }

          # Home Manager integration
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = {
              imports = [
                ./modules/home
                ./hosts/${name}.nix
              ];
              home.stateVersion = "23.11";
            };
            home-manager.extraSpecialArgs = { inherit neovim-nightly-overlay gh-review-watcher; };
          }

          # Custom overlays
          {
            nixpkgs.overlays = [
              (import ./overlays/mo.nix)
              (import ./overlays/gh.nix)
            ];
          }

          # nixpkgs config
          {
            nixpkgs.config.allowUnfree = true;
          }
        ];
      };
  in
  {
    darwinConfigurations = builtins.mapAttrs mkDarwin hosts;
    nixosConfigurations = {
      wsl = mkNixos "wsl" hosts.wsl;
    };
    homeConfigurations = {
      wsl =
        let
          inherit (hosts.wsl) system username homeDir;
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [
              (import ./overlays/mo.nix)
              (import ./overlays/gh.nix)
            ];
          };
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./modules/home
            ./hosts/wsl.nix
            {
              home.username = username;
              home.homeDirectory = homeDir;
              home.stateVersion = "23.11";
            }
          ];
          extraSpecialArgs = { inherit neovim-nightly-overlay gh-review-watcher; };
        };
    };
  };
}
