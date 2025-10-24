{ pkgs, lib, ... }: {
  # Terminal emulators

  # Kitty - GPU-accelerated terminal
  programs.kitty = {
    enable = lib.mkDefault false;
    # theme = "Dracula";
    # settings = {
    #   font_family = "JetBrains Mono";
    #   font_size = 12;
    # };
  };

  # Alacritty - GPU-accelerated terminal
  programs.alacritty = {
    enable = lib.mkDefault false;
    # settings = {
    #   font.normal.family = "JetBrains Mono";
    #   font.size = 12;
    # };
  };

  # WezTerm - GPU-accelerated terminal
  # programs.wezterm = {
  #   enable = false;
  # };
}
