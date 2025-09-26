{ config, pkgs, lib, ... }: {
  imports = [
    ./programs/helix.nix
    ./programs/neovim.nix
    ./shell/zsh.nix
    ./shell/tmux.nix
    ./devtools/default.nix
  ];

  rsydn.shell.zsh = {
    enable = true;
    plugins = [ ];
    enableVimMode = true;
  };

  programs.git.enable = true;

  home.packages = with pkgs; [ docker docker-compose ];

  rsydn.devTools = {
    enable = lib.mkDefault false;
    packages = [ ];
  };
}
