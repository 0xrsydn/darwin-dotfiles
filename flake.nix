{
  description = "Rasyid's nix-darwin dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    darwin.url = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    ghostty.url = "github:ghostty-org/ghostty";
    ghostty.inputs.nixpkgs.follows = "nixpkgs";

    nix-ai-tools.url = "github:numtide/nix-ai-tools";
    nix-ai-tools.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
  };

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, ghostty, nix-ai-tools
    , sops-nix, chaotic, ... }:
    let
      inherit (nixpkgs.lib) genAttrs;
      lib = nixpkgs.lib;

      darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];
      linuxSystems = [ "x86_64-linux" "aarch64-linux" ];
      systems = darwinSystems ++ linuxSystems;

      forEachSystem = f: genAttrs systems (system: f system);

      overlaysList = [ ghostty.overlays.default chaotic.overlays.default ];

      mkPkgs = system:
        import nixpkgs {
          inherit system;
          overlays = overlaysList;
          config.allowUnfree = true;
        };

      sharedDarwinModules = [ ./modules/darwin/system.nix ];
      sharedNixosModules =
        [ ./modules/nixos/system.nix chaotic.nixosModules.default ];

      user = "rasyidanakbar";

      mkDarwin = { system ? "aarch64-darwin", extraModules ? [ ]
        , homeFile ? ./modules/darwin/home/default.nix, }:
        let pkgs = mkPkgs system;
        in darwin.lib.darwinSystem {
          inherit system pkgs;
          specialArgs = { inherit inputs overlaysList user; };
          modules = sharedDarwinModules ++ extraModules ++ [
            home-manager.darwinModules.home-manager
            {
              nix.registry.self.flake = self;
              nixpkgs.overlays = overlaysList;

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = { inherit inputs user; };
              home-manager.users.${user} = import homeFile;
            }
          ];
        };
      mkNixos = { system ? "x86_64-linux", extraModules ? [ ]
        , homeFile ? ./modules/nixos/home/default.nix, }:
        let pkgs = mkPkgs system;
        in lib.nixosSystem {
          inherit system pkgs;
          specialArgs = { inherit inputs overlaysList user; };
          modules = sharedNixosModules ++ extraModules ++ [
            home-manager.nixosModules.home-manager
            {
              nix.registry.self.flake = self;
              nixpkgs.overlays = overlaysList;

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs user; };
              home-manager.users.${user} = import homeFile;
            }
          ];
        };
    in {
      darwinConfigurations = { macbook-pro = mkDarwin { }; };
      nixosConfigurations = {
        dev-vm = mkNixos {
          system = "x86_64-linux";
          extraModules = [ ./modules/nixos/hosts/dev-vm.nix ];
        };
        desktop = mkNixos {
          system = "x86_64-linux";
          extraModules = [ ./modules/nixos/hosts/desktop.nix ];
          homeFile = ./modules/nixos/home/desktop.nix;
        };
      };

      devShells = forEachSystem (system:
        let
          pkgs = mkPkgs system;
          python = if builtins.hasAttr "python312" pkgs then
            pkgs.python312
          else
            pkgs.python3;

          # Common arguments passed to all devshell imports
          shellArgs = { inherit pkgs lib python; };

          # Import all devshells from devshells/ directory
          importShell = name: import (./devshells + "/${name}.nix") shellArgs;

        in {
          default = importShell "default";
          python-uv = importShell "python-uv";
          ml-ai = importShell "ml-ai";
          go = importShell "go";
          web-bun = importShell "web-bun";
          rust = importShell "rust";
        });

      formatter = forEachSystem (system: (mkPkgs system).nixfmt-classic);

      packages = forEachSystem (system: { inherit (mkPkgs system) git; });
    };
}
