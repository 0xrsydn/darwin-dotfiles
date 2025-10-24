{ ... }: {
  # Desktop user configuration (for Hyprland/Niri setups)

  imports = [
    # Base CLI tools
    ../../home/rsydn/base.nix

    # Desktop additions
    ../../home/rsydn/desktop/base.nix
    ../../home/rsydn/desktop/apps/browsers.nix
    ../../home/rsydn/desktop/apps/terminals.nix

    # Choose your compositor
    ../../home/rsydn/desktop/wayland
    # Enable specific compositor in wayland/default.nix

    # Add theme when ready
    # ../../home/rsydn/desktop/themes/catppuccin.nix
  ];

  # Override options here
  # programs.kitty.enable = true;
}
