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
      function rsydn-bind-tab-autosuggest() {
        bindkey '^I' rsydn-accept-autosuggest-or-complete 2>/dev/null || true
        bindkey -M viins '^I' rsydn-accept-autosuggest-or-complete 2>/dev/null || true
      }
      function rsydn-ensure-tab-autosuggest() {
        local default_binding
        default_binding=$(bindkey '^I' 2>/dev/null || true)
        if [[ $default_binding != *rsydn-accept-autosuggest-or-complete* ]]; then
          rsydn-bind-tab-autosuggest
        fi
        local viins_binding
        viins_binding=$(bindkey -M viins '^I' 2>/dev/null || true)
        if [[ $viins_binding != *rsydn-accept-autosuggest-or-complete* ]]; then
          bindkey -M viins '^I' rsydn-accept-autosuggest-or-complete 2>/dev/null || true
        fi
      }
      autoload -Uz add-zsh-hook
      add-zsh-hook precmd rsydn-ensure-tab-autosuggest
      rsydn-ensure-tab-autosuggest
    '';
  };

  programs.git.enable = true;

  home.packages = with pkgs; [ docker docker-compose ];

  rsydn.devTools = {
    enable = lib.mkDefault false;
    packages = [ ];
  };
}
