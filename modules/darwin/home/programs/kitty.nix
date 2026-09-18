{ config, ... }:
{
  programs.kitty = {
    enable = true;

    settings = {
      shell = "/bin/zsh";

      # JetBrainsMono Nerd Font renders the Starship powerline icons.
      font_family = "JetBrainsMono Nerd Font";
      font_size = 13.0;

      background_opacity = "0.9";
      confirm_os_window_close = 0;
      enabled_layouts = "splits,stack";

      # Catppuccin Mocha colors (catppuccin/kitty themes/mocha.conf)
      background = "#1e1e2e";
      foreground = "#cdd6f4";
      cursor = "#f5e0dc";
      cursor_text_color = "#1e1e2e";
      selection_background = "#f5e0dc";
      selection_foreground = "#1e1e2e";

      # Kitty window border colors
      active_border_color = "#b4befe";
      inactive_border_color = "#6c7086";

      # Tab bar colors
      active_tab_foreground = "#11111b";
      active_tab_background = "#cba6f7";
      inactive_tab_foreground = "#cdd6f4";
      inactive_tab_background = "#181825";
      tab_bar_background = "#11111b";

      color0 = "#45475a";
      color1 = "#f38ba8";
      color2 = "#a6e3a1";
      color3 = "#f9e2af";
      color4 = "#89b4fa";
      color5 = "#f5c2e7";
      color6 = "#94e2d5";
      color7 = "#bac2de";
      color8 = "#585b70";
      color9 = "#f38ba8";
      color10 = "#a6e3a1";
      color11 = "#f9e2af";
      color12 = "#89b4fa";
      color13 = "#f5c2e7";
      color14 = "#94e2d5";
      color15 = "#a6adc8";
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
