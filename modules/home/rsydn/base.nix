{ config, pkgs, lib, ... }: {
  home.stateVersion = "24.05";

  imports = [
    ./programs/helix.nix
    ./programs/neovim.nix
    ./programs/ghostty.nix
    ./shell/nushell.nix
    ./shell/tmux.nix
    ./devtools/ai-tools.nix
    ./devtools/default.nix
  ];

  programs.nushell.enable = true;

  programs.git.enable = true;

  home.packages = with pkgs; [ docker docker-compose ];

  rsydn.aiTools.enable = lib.mkDefault true;

  rsydn.devTools = {
    enable = lib.mkDefault true;
    packages = with pkgs; [ bun cloudflared ];
  };
}
