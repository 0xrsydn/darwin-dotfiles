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
  };

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, ghostty, ... }:
    let
      inherit (nixpkgs.lib) genAttrs;

      systems = [ "aarch64-darwin" "x86_64-darwin" ];

      forEachSystem = f: genAttrs systems (system: f system);

      overlaysList = [ ghostty.overlays.default ];

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
              home-manager.extraSpecialArgs = { inherit inputs user; };
              home-manager.users.${user} = import homeFile;
            }
          ];
        };
    in {
      darwinConfigurations = { macbook-pro = mkDarwin { }; };

      devShells = forEachSystem (system:
        let pkgs = mkPkgs system;
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [ git nixfmt-classic ];
            shellHook = ''
              echo "Loaded default shell for ${system}"
            '';
          };

        });

      formatter = forEachSystem (system: (mkPkgs system).nixfmt-classic);

      packages = forEachSystem (system: { inherit (mkPkgs system) git; });
    };
}
