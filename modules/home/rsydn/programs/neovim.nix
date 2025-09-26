{ inputs, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  lazyvim = let nvimPackages = inputs."nvim-bundle".packages;
  in if builtins.hasAttr system nvimPackages then
    (builtins.getAttr system nvimPackages).neovim
  else
    pkgs.neovim; # upstream bundle only exports x86_64-linux for now
in {
  programs.neovim = {
    enable = true;
    package = lazyvim;
    withNodeJs = true;
    withPython3 = true;
  };
}
