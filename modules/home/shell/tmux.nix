{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.tmux = {
    enable = lib.mkDefault true;
    clock24 = true;
    historyLimit = 20000;
    mouse = true;
    baseIndex = 1;
    prefix = "C-a";
    escapeTime = 0;
    aggressiveResize = true;
    plugins = [
      {
        plugin = pkgs.tmuxPlugins.catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor "mocha"
          set -g @catppuccin_window_status_style "rounded"
        '';
      }
    ];
    extraConfig = ''
      # Terminal configuration for proper colors and features
      set-option -g default-terminal "screen-256color"
      set-option -ga terminal-overrides ",*256col*:Tc"
      set-option -g focus-events on
      # Avoid CSI-u newline remapping that breaks Neovim pastes
      set -as terminal-features 'xterm-kitty:clipboard,RGB'
      set -g status-interval 5
        setw -g automatic-rename on
        set -g renumber-windows on
        bind r source-file ~/.tmux.conf \; display-message "tmux reloaded"
      bind | split-window -h
      bind - split-window -v
      unbind '"'
      unbind %
      set -g display-panes-time 1500
      bind C-k send-keys -R \; send-keys C-l \; clear-history

      # Vim-style pane navigation (prefix + hjkl)
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # No-prefix pane switching (Option + arrow)
      bind -n M-Left select-pane -L
      bind -n M-Right select-pane -R
      bind -n M-Up select-pane -U
      bind -n M-Down select-pane -D

      # Pane resizing (prefix + Shift+hjkl)
      bind H resize-pane -L 5
      bind J resize-pane -D 5
      bind K resize-pane -U 5
      bind L resize-pane -R 5
      # Start Zsh by default and keep Nushell available on prefix + C-n.
      set -g default-shell "/bin/zsh"
      set -g default-command "/bin/zsh --login"
      bind-key C-n new-window -n nushell "${config.home.profileDirectory}/bin/nu --login"
    '';
  };
}
