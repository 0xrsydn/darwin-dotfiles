{ inputs, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  lazyvim = inputs."nvim-bundle".packages.${system}.neovim;
in {
  programs.neovim = {
    enable = true;
    package = lazyvim;
    withNodeJs = true;
    withPython3 = true;
  };
}
