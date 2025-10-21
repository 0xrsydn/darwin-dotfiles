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

    zig-overlay.url = "github:mitchellh/zig-overlay";
    zig-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, ghostty, nix-ai-tools
    , sops-nix, ... }:
    let
      inherit (nixpkgs.lib) genAttrs;
      lib = nixpkgs.lib;

      darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];
      linuxSystems = [ "x86_64-linux" "aarch64-linux" ];
      systems = darwinSystems ++ linuxSystems;

      forEachSystem = f: genAttrs systems (system: f system);

      overlaysList = [ ghostty.overlays.default ];

      zigOverlay = if builtins.hasAttr "zig-overlay" inputs then
        inputs."zig-overlay"
      else
        null;

      mkPkgs = system:
        import nixpkgs {
          inherit system;
          overlays = overlaysList;
          config.allowUnfree = true;
        };

      sharedDarwinModules = [ ./modules/darwin/system.nix ];
      sharedNixosModules = [ ./modules/nixos/system.nix ];

      user = "rasyidanakbar";

      mkDarwin = { system ? "aarch64-darwin", extraModules ? [ ]
        , homeFile ? ./modules/darwin/home/default.nix }:
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
        , homeFile ? ./modules/nixos/home/default.nix }:
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
      nixosConfigurations = { };

      devShells = forEachSystem (system:
        let
          pkgs = mkPkgs system;
          python = if builtins.hasAttr "python312" pkgs then
            pkgs.python312
          else
            pkgs.python3;

          # Zig overlay setup for zig-nightly shell
          zigPackages =
            if zigOverlay != null && builtins.hasAttr "packages" zigOverlay then
              zigOverlay.packages
            else
              { };

          zigCandidate =
            if zigOverlay != null && system == "aarch64-darwin" then
              lib.attrByPath [ system "master" "zig" ] null zigPackages
            else
              null;

          zigCandidateBroken = if zigCandidate != null then
            if zigCandidate ? meta && zigCandidate.meta ? broken then
              zigCandidate.meta.broken
            else
              false
          else
            true;

          zigFallback = pkgs.zig;
          zigFallbackBroken =
            if zigFallback ? meta && zigFallback.meta ? broken then
              zigFallback.meta.broken
            else
              false;

          zigPackage =
            if zigCandidate != null && zigCandidateBroken == false then
              zigCandidate
            else if zigFallbackBroken == false then
              zigFallback
            else
              null;

          zlsBroken = if pkgs.zls ? meta && pkgs.zls.meta ? broken then
            pkgs.zls.meta.broken
          else
            false;

          # Common arguments passed to all devshell imports
          shellArgs = { inherit pkgs lib python zigPackage; };

          # Import all devshells from devshells/ directory
          importShell = name: import (./devshells + "/${name}.nix") shellArgs;

        in {
          default = importShell "default";
          python-uv = importShell "python-uv";
          ml-ai = importShell "ml-ai";
          go = importShell "go";
          web-bun = importShell "web-bun";
          rust = importShell "rust";
        } // lib.optionalAttrs (zigPackage != null && zlsBroken == false) {
          zig-nightly = importShell "zig-nightly";
        });

      formatter = forEachSystem (system: (mkPkgs system).nixfmt-classic);

      packages = forEachSystem (system: { inherit (mkPkgs system) git; });
    };
}
