{ lib, pkgs, ... }: {
  # Niri user configuration
  programs.niri = {
    settings = {
      # Minimal config - expand as needed
      input = { keyboard.xkb = { layout = "us"; }; };

      # Example keybinds
      binds = {
        "Mod+Return".action.spawn = [ "kitty" ];
        "Mod+Q".action.close-window = { };
        "Mod+F".action.fullscreen-window = { };

        # Focus movement
        "Mod+H".action.focus-column-left = { };
        "Mod+L".action.focus-column-right = { };
        "Mod+J".action.focus-window-down = { };
        "Mod+K".action.focus-window-up = { };
      };

      layout = {
        gaps = 8;
        center-focused-column = "never";
      };
    };
  };

  # Niri utilities
  home.packages = with pkgs;
    [
      # fuzzel     # Launcher (recommended for niri)
      # waybar     # Status bar
      # dunst      # Notifications
    ];
}
