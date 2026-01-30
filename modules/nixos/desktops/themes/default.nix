{
  lib,
  pkgs,
  user,
  ...
}:
{
  # Default theme configuration for desktop
  # Simple Adwaita-dark theme that works across all desktop environments
  # Switch to catppuccin.nix or create your own for custom themes

  home-manager.users.${user} = {
    # GTK theming - Adwaita Dark
    gtk = {
      enable = lib.mkDefault true;
      theme = lib.mkDefault {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
      iconTheme = lib.mkDefault {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
      };
    };

    # Qt theming - Use GTK theme for consistency
    qt = {
      enable = lib.mkDefault true;
      platformTheme.name = lib.mkDefault "gtk";
      style.name = lib.mkDefault "adwaita-dark";
    };

    # XDG user directories for desktop environments
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
    };
  };
}
