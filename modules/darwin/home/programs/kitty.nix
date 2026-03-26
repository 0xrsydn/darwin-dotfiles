{ config, ... }:
{
  programs.kitty = {
    enable = true;

    settings = {
      background_opacity = "0.9";
      confirm_os_window_close = 0;
      enabled_layouts = "splits,stack";

      # Gruvbox colors
      background = "#282828";
      foreground = "#ebdbb2";
      cursor = "#ebdbb2";
      cursor_text_color = "#282828";
      selection_background = "#ebdbb2";
      selection_foreground = "#282828";

      color0 = "#282828";
      color1 = "#cc241d";
      color2 = "#98971a";
      color3 = "#d79921";
      color4 = "#458588";
      color5 = "#b16286";
      color6 = "#689d6a";
      color7 = "#a89984";
      color8 = "#928374";
      color9 = "#fb4934";
      color10 = "#b8bb26";
      color11 = "#fabd2f";
      color12 = "#83a598";
      color13 = "#d3869b";
      color14 = "#8ec07c";
      color15 = "#ebdbb2";
    };

    keybindings = {
      # Split bindings (cmd+a prefix, matching old ghostty bindings)
      "cmd+a>v" = "launch --location=vsplit --cwd=current";
      "cmd+a>s" = "launch --location=hsplit --cwd=current";
      # Navigation
      "cmd+a>h" = "neighboring_window left";
      "cmd+a>j" = "neighboring_window bottom";
      "cmd+a>k" = "neighboring_window top";
      "cmd+a>l" = "neighboring_window right";
      # Other actions
      "cmd+a>n" = "new_window_with_cwd";
      "cmd+a>z" = "toggle_layout stack";
      "cmd+a>x" = "close_window";
    };
  };
}
