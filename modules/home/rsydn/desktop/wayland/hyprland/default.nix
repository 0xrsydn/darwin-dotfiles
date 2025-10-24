{ lib, pkgs, ... }:
{
  # Hyprland user configuration
  wayland.windowManager.hyprland = {
    enable = lib.mkDefault true;
    xwayland.enable = lib.mkDefault true;

    settings = {
      # Minimal config - expand as needed
      "$mod" = "SUPER";

      # Example keybinds
      bind = [
        "$mod, Return, exec, kitty" # Terminal
        "$mod, Q, killactive"
        "$mod, M, exit"
        "$mod, F, fullscreen"
        "$mod, Space, togglefloating"

        # Move focus
        "$mod, h, movefocus, l"
        "$mod, l, movefocus, r"
        "$mod, k, movefocus, u"
        "$mod, j, movefocus, d"
      ];

      # Example settings
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
      };

      decoration = {
        rounding = 8;
      };
    };
  };

  # Hyprland utilities
  home.packages = with pkgs; [
    # wofi       # Launcher
    # waybar     # Status bar
    # dunst      # Notifications
  ];
}
