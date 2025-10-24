{ pkgs, lib, ... }:
{
  imports = [ ./base.nix ];

  # Niri - Scrollable-tiling Wayland compositor
  programs.niri = {
    enable = lib.mkDefault true;
  };

  # Wayland-specific portal
  xdg.portal.wlr.enable = lib.mkDefault true;

  # Essential Wayland tools
  environment.systemPackages = with pkgs; [
    # Wayland essentials
    wayland
    wl-clipboard

    # Screenshot tools
    grim
    slurp

    # Add your preferred apps here
    # kitty        # Terminal
    # fuzzel       # Launcher (recommended for niri)
    # waybar       # Bar
  ];
}
