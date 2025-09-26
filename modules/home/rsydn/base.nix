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
      function rsydn-accept-autosuggest-or-complete() {
        if [[ -n "''${POSTDISPLAY:-}" ]]; then
          zle autosuggest-accept
        else
          zle expand-or-complete
        fi
      }
      zle -N rsydn-accept-autosuggest-or-complete
      bindkey '^I' rsydn-accept-autosuggest-or-complete
    '';
  };

  programs.git.enable = true;

  home.packages = with pkgs; [ docker docker-compose ];

  rsydn.devTools = {
    enable = lib.mkDefault false;
    packages = [ ];
  };
}
