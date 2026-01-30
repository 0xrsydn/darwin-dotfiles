{
  lib,
  pkgs,
  user,
  ...
}:
{
  imports = [ ./base.nix ];

  # System-level: KDE Plasma 6
  services.desktopManager.plasma6.enable = lib.mkDefault true;

  # SDDM display manager
  services.displayManager.sddm = {
    enable = lib.mkDefault true;
    wayland.enable = lib.mkDefault true;
  };

  # System packages: KDE applications
  environment.systemPackages = with pkgs; [
    # KDE applications (uncomment as needed)
    # kdePackages.kate          # Text editor
    # kdePackages.dolphin       # File manager
    # kdePackages.konsole       # Terminal
    # kdePackages.okular        # Document viewer
    # kdePackages.gwenview      # Image viewer
    # kdePackages.spectacle     # Screenshot tool
  ];

  # User-level: KDE Plasma settings (optional)
  home-manager.users.${user} = {
    # KDE Plasma configuration via Home Manager (optional)
    # programs.plasma = {
    #   enable = true;
    #   workspace = {
    #     theme = "breeze-dark";
    #     colorScheme = "BreezeDark";
    #   };
    # };

    # User packages for KDE environment
    home.packages = with pkgs; [
      # Add user-specific apps here
    ];
  };
}
