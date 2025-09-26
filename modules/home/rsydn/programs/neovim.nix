{ inputs, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  nvimPackages = inputs."nvim-bundle".packages or { };
  neovimUnwrapped = if builtins.hasAttr system nvimPackages then
    let bundle = builtins.getAttr system nvimPackages;
    in bundle.neovim-unwrapped or pkgs.neovim-unwrapped
  else
    pkgs.neovim-unwrapped;
in {
  programs.neovim = {
    enable = true;
    package = neovimUnwrapped;
    withNodeJs = true;
    withPython3 = true;
  };
}
