{ config, ... }:
{
  programs.ghostty = {
    enable = true;
    package = null;

    settings = {
      theme = "gruvbox";
      background-opacity = 0.9;
      shell-integration = "detect";
      working-directory = "home";
      window-inherit-working-directory = true;
      keybind = [
        "super+a>n=new_window"
        # Split bindings - using v and s instead of | and - for better reliability
        "super+a>v=new_split:right"
        "super+a>s=new_split:down"
        # Navigation
        "super+a>h=goto_split:left"
        "super+a>j=goto_split:down"
        "super+a>k=goto_split:up"
        "super+a>l=goto_split:right"
        # Other actions
        "super+a>z=toggle_split_zoom"
        "super+a>x=close_surface"
        "super+a>r=reload_config"
      ];
    };

    themes.gruvbox = {
      background = "282828";
      foreground = "ebdbb2";
      cursor-color = "ebdbb2";
      cursor-text = "282828";
      selection-background = "ebdbb2";
      selection-foreground = "282828";
      palette = [
        "0=#282828"
        "1=#cc241d"
        "2=#98971a"
        "3=#d79921"
        "4=#458588"
        "5=#b16286"
        "6=#689d6a"
        "7=#a89984"
        "8=#928374"
        "9=#fb4934"
        "10=#b8bb26"
        "11=#fabd2f"
        "12=#83a598"
        "13=#d3869b"
        "14=#8ec07c"
        "15=#ebdbb2"
      ];
    };
  };
}
