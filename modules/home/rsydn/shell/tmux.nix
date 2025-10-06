{ lib, pkgs, ... }: {
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
      plugin = pkgs.tmuxPlugins.dracula;
      extraConfig = ''
        set -g @dracula-pane-border-style "fg=#44475a"
        set -g @dracula-plugins "cpu-usage battery network-bandwidth time"
        set -g @dracula-show-empty-plugins off
        set -g @dracula-refresh-rate 5
      '';
    }];
    extraConfig = ''
      set -s extended-keys on
      set -as terminal-features 'xterm-ghostty:extkeys'
      set-option -g status-style "bg=#282a36 fg=#f8f8f2"
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
    '';
  };
}
