{ config, lib, pkgs, ... }: {
  programs.tmux = {
    enable = lib.mkDefault true;
    clock24 = true;
    historyLimit = 20000;
    mouse = true;
    baseIndex = 1;
    prefix = "C-a";
    escapeTime = 0;
    aggressiveResize = true;
    plugins = [{
      plugin = pkgs.tmuxPlugins.gruvbox;
    }];
    extraConfig = ''
      # Terminal configuration for proper colors and features
      set-option -g default-terminal "screen-256color"
      set-option -ga terminal-overrides ",*256col*:Tc"
      set-option -g focus-events on
      # Avoid CSI-u newline remapping that breaks Neovim pastes
      set -as terminal-features 'xterm-ghostty:bpaste,clipboard,RGB'
      set -g status-interval 5
        setw -g automatic-rename on
        set -g renumber-windows on
        bind r source-file ~/.tmux.conf \; display-message "tmux reloaded"
        bind | split-window -h
      bind - split-window -v
      unbind '"'
      unbind %
      set -g display-panes-time 1500
      bind k send-keys -R \; send-keys C-l \; clear-history
      # Ensure tmux panes spawn login nu so Starship integration runs
      set -g default-shell "${config.home.profileDirectory}/bin/nu"
      set -g default-command "${config.home.profileDirectory}/bin/nu --login"
    '';
  };
}
