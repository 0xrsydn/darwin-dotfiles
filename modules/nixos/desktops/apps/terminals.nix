{
  lib,
  pkgs,
  user,
  ...
}:
{
  # Terminal emulator configurations for desktop users

  home-manager.users.${user} = {
    # Provide JetBrains Mono font locally for Alacritty.
    home.packages = with pkgs; [ jetbrains-mono ];

    # Ensure Kitty stays disabled when desktop module is imported.
    programs.kitty.enable = lib.mkForce false;

    # Configure Alacritty as the default terminal with Dracula theme.
    programs.alacritty = {
      enable = true;
      settings = {
        window.opacity = 0.85;

        font = {
          normal = {
            family = "JetBrains Mono";
            style = "Regular";
          };
          bold = {
            family = "JetBrains Mono";
            style = "Bold";
          };
          italic = {
            family = "JetBrains Mono";
            style = "Italic";
          };
          bold_italic = {
            family = "JetBrains Mono";
            style = "Bold Italic";
          };
          size = 12.0;
        };

        colors = {
          primary = {
            background = "#282a36";
            foreground = "#f8f8f2";
            bright_foreground = "#ffffff";
          };

          cursor = {
            text = "#282a36";
            cursor = "#f8f8f2";
          };

          vi_mode_cursor = {
            text = "CellBackground";
            cursor = "CellForeground";
          };

          selection = {
            text = "CellForeground";
            background = "#44475a";
          };

          normal = {
            black = "#21222c";
            red = "#ff5555";
            green = "#50fa7b";
            yellow = "#f1fa8c";
            blue = "#bd93f9";
            magenta = "#ff79c6";
            cyan = "#8be9fd";
            white = "#f8f8f2";
          };

          bright = {
            black = "#6272a4";
            red = "#ff6e6e";
            green = "#69ff94";
            yellow = "#ffffa5";
            blue = "#d6acff";
            magenta = "#ff92df";
            cyan = "#a4ffff";
            white = "#ffffff";
          };

          search = {
            matches = {
              foreground = "#44475a";
              background = "#50fa7b";
            };
            focused_match = {
              foreground = "#44475a";
              background = "#ffb86c";
            };
          };

          footer_bar = {
            background = "#282a36";
            foreground = "#f8f8f2";
          };

          hints = {
            start = {
              foreground = "#282a36";
              background = "#f1fa8c";
            };
            end = {
              foreground = "#f1fa8c";
              background = "#282a36";
            };
          };
        };
      };
    };

    # Keep WezTerm disabled to avoid conflicting terminal defaults.
    programs.wezterm.enable = lib.mkForce false;
  };
}
