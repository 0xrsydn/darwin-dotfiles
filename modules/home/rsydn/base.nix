{ config, pkgs, lib, ... }: {
  home.stateVersion = "24.05";

  imports = [
    ./programs/helix.nix
    ./programs/neovim.nix
    ./programs/ghostty.nix
    ./shell/nushell.nix
    ./shell/tmux.nix
    ./devtools/ai-tools.nix
    ./devtools/languages.nix
    ./devtools/default.nix
    ./secrets.nix
  ];

  programs.nushell.enable = true;

  programs.git.enable = true;

  home.packages = with pkgs; [ docker docker-compose ];

  rsydn.aiTools.enable = lib.mkDefault true;

  rsydn.devTools = {
    enable = lib.mkDefault true;
    packages = with pkgs; [
      ast-grep
      cloudflared
      ffmpeg
      fzf
      htop
      jetbrains-mono
      jq
      lazydocker
      lazygit
      lorri
      neovim
      pandoc
      ripgrep
      tmux
      tree
      vim
      wget
      yq
    ];
  };

  rsydn.languages.enable = lib.mkDefault true;

  rsydn.secrets.enable = lib.mkDefault true;
}
