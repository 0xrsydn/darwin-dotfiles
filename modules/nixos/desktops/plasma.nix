{ lib, ... }:
{
  imports = [ ./base.nix ];

  # KDE Plasma 6
  services.desktopManager.plasma6.enable = lib.mkDefault true;

  # SDDM display manager
  services.displayManager.sddm = {
    enable = lib.mkDefault true;
    wayland.enable = lib.mkDefault true;
  };

  # KDE apps are managed by Plasma
  # Add extra packages in your host config if needed
}
