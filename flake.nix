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

    nvim-bundle.url = "github:jla2000/nvim-bundle";
    nvim-bundle.inputs.nixpkgs.follows = "nixpkgs";

    nix-ai-tools.url = "github:numtide/nix-ai-tools";
    nix-ai-tools.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    zig-overlay.url = "github:mitchellh/zig-overlay";
    zig-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ self, nixpkgs, darwin, home-manager, ghostty, nix-ai-tools, sops-nix, ... }:
    let
      inherit (nixpkgs.lib) genAttrs;
      lib = nixpkgs.lib;

      systems = [ "aarch64-darwin" "x86_64-darwin" ];

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

      sharedModules = [ ./modules/darwin/system.nix ];

      user = "rasyidanakbar";

      mkDarwin = { system ? "aarch64-darwin", extraModules ? [ ]
        , homeFile ? ./modules/home/rsydn/base.nix }:
        let pkgs = mkPkgs system;
        in darwin.lib.darwinSystem {
          inherit system pkgs;
          specialArgs = { inherit inputs overlaysList user; };
          modules = sharedModules ++ extraModules ++ [
            home-manager.darwinModules.home-manager
            {
              nix.registry.self.flake = self;
              nixpkgs.overlays = overlaysList;

              users.users.${user}.home = "/Users/${user}";

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = { inherit inputs user; };
              home-manager.users.${user} = import homeFile;
            }
          ];
        };
    in {
      darwinConfigurations = { macbook-pro = mkDarwin { }; };

      devShells = forEachSystem (system:
        let
          pkgs = mkPkgs system;
          python = if builtins.hasAttr "python312" pkgs then
            pkgs.python312
          else
            pkgs.python3;

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

          zigShell =
            lib.optionalAttrs (zigPackage != null && zlsBroken == false) {
              zig-nightly = pkgs.mkShell {
                name = "zig-nightly";
                packages =
                  [ zigPackage pkgs.zls pkgs.pkg-config pkgs.cmake pkgs.gdb ];
                shellHook = ''
                  mkdir -p "$PWD/.cache/zig"
                  export ZIG_GLOBAL_CACHE_DIR="$PWD/.cache/zig"
                  echo "Zig shell using ${zigPackage.pname or "zig"} ${
                    zigPackage.version or ""
                  }"
                '';
              };
            };

          baseShells = {
            default = pkgs.mkShell {
              name = "default";
              packages = with pkgs; [ git nixfmt-classic ];
              shellHook = ''
                echo "Loaded default shell for ${system}"
              '';
            };

            python-uv = pkgs.mkShell {
              name = "python-uv";
              packages = [ python pkgs.uv pkgs.ruff pkgs.pyright ];
              shellHook = ''
                export UV_PYTHON="${python}/bin/python3"
                export UV_LINK_MODE=copy
                echo "Python (uv) shell ready"
              '';
            };

            go = pkgs.mkShell {
              name = "go";
              packages = with pkgs; [ go gopls golangci-lint delve git ];
              shellHook = ''
                mkdir -p "$PWD/.cache/go" "$PWD/.cache/gomod"
                export GOPATH="$PWD/.cache/go"
                export GOMODCACHE="$PWD/.cache/gomod"
                echo "Go toolchain shell ready"
              '';
            };

            web-bun = pkgs.mkShell {
              name = "web-bun";
              packages = with pkgs; [
                bun
                nodejs_20
                yarn
                esbuild
                vscode-langservers-extracted
              ];
              shellHook = ''
                mkdir -p "$PWD/.cache/bun"
                export BUN_INSTALL_CACHE="$PWD/.cache/bun"
                echo "Bun/Node web shell ready"
              '';
            };
          };
        in baseShells // zigShell);

      formatter = forEachSystem (system: (mkPkgs system).nixfmt-classic);

      packages = forEachSystem (system: { inherit (mkPkgs system) git; });
    };
}
