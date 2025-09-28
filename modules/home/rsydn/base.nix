{ config, pkgs, lib, ... }: {
  home.stateVersion = "24.05";

  imports = [
    ./programs/helix.nix
    ./programs/neovim.nix
    ./programs/ghostty.nix
    ./shell/zsh.nix
    ./shell/tmux.nix
    ./devtools/default.nix
  ];

  rsydn.shell.zsh = {
    enable = true;
    enableVimMode = true;
    powerlevel10kConfigFile = ./shell/p10k.zsh;
    aliases = { ll = "ls -alF"; };
    extraAfter = ''
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"
    '';
  };

  programs.git.enable = true;

  home.packages = with pkgs; [ docker docker-compose ];

  rsydn.devTools = {
    enable = lib.mkDefault true;
    packages = with pkgs; [ bun cloudflared ];
  };
}
