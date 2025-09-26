{
  description = "Rasyid's nix-darwin dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    darwin.url = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    ghostty.url = "github:ghostty-org/ghostty";
    ghostty.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, darwin, home-manager, ghostty, ... }:
    let
      inherit (nixpkgs.lib) genAttrs;

      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      forEachSystem = f: genAttrs systems (system: f system);

      overlaysList =
        [ ghostty.overlays.default ];

      mkPkgs = system:
        import nixpkgs {
          inherit system;
          overlays = overlaysList;
          config.allowUnfree = true;
        };

      mkPkgsUnstable = system:
        import nixpkgs-unstable {
          inherit system;
          overlays = overlaysList;
          config.allowUnfree = true;
        };

      sharedModules = [
        ./modules/darwin/system.nix
      ];

      user = "rsydn";

      mkDarwin = { hostname, system ? "aarch64-darwin", extraModules ? [ ], homeFile ? ./modules/home/rsydn/base.nix }:
        let
          pkgs = mkPkgs system;
          pkgsUnstable = mkPkgsUnstable system;
        in
          darwin.lib.darwinSystem {
            inherit system pkgs;
            specialArgs = {
              inherit inputs overlaysList pkgsUnstable user;
            };
            modules =
              sharedModules
              ++ extraModules
              ++ [
                home-manager.darwinModules.home-manager
                {
                  nix.registry.self.flake = self;
                  nixpkgs.overlays = overlaysList;

                  users.users.${user}.home = "/Users/${user}";

                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  home-manager.extraSpecialArgs = {
                    inherit inputs pkgsUnstable user;
                  };
                  home-manager.users.${user} = import homeFile;
                }
              ];
          };
    in {
      darwinConfigurations = {
        macbook-pro = mkDarwin {
          hostname = "macbook-pro";
        };
      };

      devShells = forEachSystem (system:
        let
          pkgs = mkPkgs system;
          pkgsUnstable = mkPkgsUnstable system;
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [
              git
              nixfmt-classic
            ];
            shellHook = ''
              echo "Loaded default shell for ${system}"
            '';
          };

        });

      formatter = forEachSystem (system: (mkPkgs system).nixfmt-classic);

      packages = forEachSystem (system: {
        inherit (mkPkgs system) git;
      });
    };
}
