{ pkgs, ... }:

pkgs.mkShell {
  name = "default";
  packages = with pkgs; [ git nixfmt-classic ];
  shellHook = ''
    echo "Loaded default shell for dotfiles development"
  '';
}
