{ lib, pkgs, ... }: {
  # Shared desktop settings (imported by all DEs)

  # XDG portals for desktop integration
  xdg.portal = {
    enable = lib.mkDefault true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Policy kit for privilege escalation
  security.polkit.enable = lib.mkDefault true;

  # GVFS for trash, mounting, etc
  services.gvfs.enable = lib.mkDefault true;

  # Common desktop packages
  environment.systemPackages = with pkgs; [
    # File managers (choose one)
    # nautilus  # GNOME
    # dolphin   # KDE
    # thunar    # XFCE

    # Basic utilities
    pavucontrol # Audio control
    networkmanagerapplet # Network management GUI
  ];
}
