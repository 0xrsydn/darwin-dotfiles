{
  description = "Rasyid's nix-darwin dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Stable nixpkgs for pinning packages with bugs in unstable (e.g., git 2.51.x)
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    darwin.url = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    ghostty.url = "github:ghostty-org/ghostty";
    ghostty.inputs.nixpkgs.follows = "nixpkgs";

    # Latest llm-agents for most tools (uses its own nixpkgs for compatibility)
    llm-agents.url = "github:numtide/llm-agents.nix";

    # Pinned llm-agents for Claude Code 2.0.64 (uses its own nixpkgs for compatibility)
    llm-agents-pinned.url =
      "github:numtide/llm-agents.nix/4a12b5bef5a82b71da765603df5192c511a60cc2";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    try.url = "github:tobi/try";
    try.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, ghostty, llm-agents
    , llm-agents-pinned, sops-nix, chaotic, try, ... }:
    let
      inherit (nixpkgs.lib) genAttrs;
      lib = nixpkgs.lib;

      darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];
      linuxSystems = [ "x86_64-linux" "aarch64-linux" ];
      systems = darwinSystems ++ linuxSystems;

      forEachSystem = f: genAttrs systems (system: f system);

      # Overlay to pin git to stable version (avoids 2.51.x FamilyDisplayName warning on macOS)
      gitOverlay = final: prev: {
        git = (import inputs.nixpkgs-stable {
          system = prev.stdenv.hostPlatform.system;
        }).git;
      };

      # Overlay to skip syrupy tests (broken in nixpkgs unstable)
      # Uses pythonPackagesExtensions to apply to all Python versions
      syrupyOverlay = final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (pyFinal: pyPrev: {
            syrupy = pyPrev.syrupy.overrideAttrs (old: { doCheck = false; });
          })
        ];
      };

      overlaysList =
        [ ghostty.overlays.default
          chaotic.overlays.default
          gitOverlay
          syrupyOverlay
        ];

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
        let
          pkgs = mkPkgs system;
          customPkgs = import ./packages { inherit pkgs lib llm-agents; };
        in darwin.lib.darwinSystem {
          inherit pkgs;
          system = pkgs.stdenv.hostPlatform.system;
          specialArgs = { inherit inputs overlaysList user; };
          modules = sharedDarwinModules ++ extraModules ++ [
            home-manager.darwinModules.home-manager
            {
              nix.registry.self.flake = self;
              nixpkgs.overlays = overlaysList;

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = {
                inherit inputs user try customPkgs;
              };
              home-manager.users.${user} = import homeFile;
            }
          ];
        };
      mkNixos = { system ? "x86_64-linux", extraModules ? [ ]
        , homeFile ? ./modules/nixos/home/default.nix, }:
        let
          pkgs = mkPkgs system;
          customPkgs = import ./packages { inherit pkgs lib llm-agents; };
        in lib.nixosSystem {
          inherit pkgs;
          system = pkgs.stdenv.hostPlatform.system;
          specialArgs = { inherit inputs overlaysList user; };
          modules = sharedNixosModules ++ extraModules ++ [
            home-manager.nixosModules.home-manager
            {
              nix.registry.self.flake = self;
              nixpkgs.overlays = overlaysList;

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                inherit inputs user try customPkgs;
              };
              home-manager.users.${user} = import homeFile;
            }
          ];
        };
    in {
      darwinConfigurations = { macbook-pro = mkDarwin { }; };
      nixosConfigurations = {
        # Temporarily disabled for testing
        # dev-vm = mkNixos {
        #   system = "x86_64-linux";
        #   extraModules = [ ./hosts/dev-vm.nix ];
        #   # Uses default homeFile: ./modules/nixos/home/default.nix
        # };
        # desktop = mkNixos {
        #   system = "x86_64-linux";
        #   extraModules = [ ./hosts/desktop.nix ];
        #   # Home Manager configs are imported directly in desktop modules
        #   # No homeFile needed - using inline home-manager.users.${user}
        #   homeFile = ./modules/nixos/home/default.nix;
        # };
      };

      devShells = forEachSystem (system:
        let
          pkgs = mkPkgs system;
          python = if builtins.hasAttr "python312" pkgs then
            pkgs.python312
          else
            pkgs.python3;

          # Custom packages
          customPkgs = import ./packages { inherit pkgs lib llm-agents; };

          # Common arguments passed to all devshell imports
          shellArgs = { inherit pkgs lib python customPkgs; };

          # Import all shells from shells/ directory
          importShell = name: import (./shells + "/${name}.nix") shellArgs;

        in {
          default = importShell "default";
          python-uv = importShell "python-uv";
          ai-notebook = importShell "ai-notebook";
          jupyter-notebook = importShell "jupyter-notebook";
          go = importShell "go";
          web-bun = importShell "web-bun";
          rust = importShell "rust";
          ai-agent = importShell "ai-agent";
          effect-ts = importShell "effect-ts";
        });

      formatter = forEachSystem (system: (mkPkgs system).nixfmt-classic);

      packages = forEachSystem (system:
        let
          pkgs = mkPkgs system;
          customPkgs = import ./packages { inherit pkgs lib llm-agents; };
        in customPkgs // { inherit (pkgs) git; });

      checks = forEachSystem (system:
        let
          pkgs = mkPkgs system;
          customPkgs = import ./packages { inherit pkgs lib llm-agents; };
        in { inherit (customPkgs) opencode; });
    };
}
