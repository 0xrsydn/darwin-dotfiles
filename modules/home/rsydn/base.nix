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
        local original_buffer=$BUFFER
        local original_cursor=$CURSOR
        zle autosuggest-accept 2>/dev/null
        if [[ $BUFFER == "$original_buffer" && $CURSOR -eq $original_cursor ]]; then
          zle expand-or-complete
        fi
      }
      zle -N rsydn-accept-autosuggest-or-complete
      for keymap in main viins; do
        bindkey -M "$keymap" '^I' rsydn-accept-autosuggest-or-complete || true
      done
    '';
  };

  programs.git.enable = true;

  home.packages = with pkgs; [ docker docker-compose ];

  rsydn.devTools = {
    enable = lib.mkDefault false;
    packages = [ ];
  };
}
